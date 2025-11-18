// swiftlint:disable file_length type_body_length
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit
#if os(iOS)
import PDFKit
import WebKit
#endif

final class SentryUIRedactBuilder {
    // MARK: - Types

    /// Type used to represented a view that needs to be redacted
    struct ClassIdentifier: Hashable {
        /// String representation of the class
        ///
        /// We deliberately store class identities as strings (e.g. "SwiftUI._UIGraphicsView")
        /// instead of `AnyClass` to avoid triggering Objective‑C `+initialize` on UIKit internals
        /// or private classes when running off the main thread. The string is obtained via
        /// `type(of: someObject).description()`.
        let classId: String

        /// Optional filter for layer
        ///
        /// Some view types are reused for multiple purposes. For example, `SwiftUI._UIGraphicsView`
        /// is used both as a structural background (should not be redacted) and as a drawing surface
        /// for images when paired with `SwiftUI.ImageLayer` (should be redacted). When `layerId` is
        /// provided we only match a view if its backing layer’s type description equals the filter.
        let layerId: String?

        /// Initializes a new instance of the extended class identifier using a class ID.
        ///
        /// - parameter classId: The class name.
        /// - parameter layerId: The layer name.
        init(classId: String, layerId: String? = nil) {
            self.classId = classId
            self.layerId = layerId
        }

        /// Initializes a new instance of the extended class identifier using an Objective-C type.
        ///
        /// - parameter objcType: The object type.
        /// - parameter layerId: The layer name.
        init<T: NSObject>(objcType: T.Type, layerId: String? = nil) {
            self.classId = objcType.description()
            self.layerId = layerId
        }

        /// Initializes a new instance of the extended class identifier using a Swift class.
        ///
        /// - parameter class: The class.
        /// - parameter layerId: The layer name.
        init(class: AnyClass, layerId: String? = nil) {
            self.classId = `class`.description()
            self.layerId = layerId
        }

        /// Initializes a new instance of the extended class identifier using a Swift class.
        ///
        /// - parameter class: The class.
        /// - parameter layerId: The layer.
        init(class: AnyClass, layer: AnyClass) {
            self.classId = `class`.description()
            self.layerId = layer.description()
        }
    }

    // MARK: - Constants

    /// Class identifier for ``CameraUI.ChromeSwiftUIView``, if it exists.
    ///
    /// This object identifier is used to identify views of this class type during the redaction process.
    /// This workaround is specifically for Xcode 16 building for iOS 26 where accessing CameraUI.ModeLoupeLayer
    /// causes a crash due to unimplemented init(layer:) initializer.
    private static let cameraSwiftUIViewClassId = ClassIdentifier(classId: "CameraUI.ChromeSwiftUIView")

    // MARK: - Properties

    /// This is a wrapper which marks it's direct children to be ignored
    private var ignoreContainerClassIdentifier: ObjectIdentifier?

    /// This is a wrapper which marks it's direct children to be redacted
    private var redactContainerClassIdentifier: ObjectIdentifier?

    /// This is a list of UIView subclasses that will be ignored during redact process
    ///
    /// Stored as `ExtendedClassIdentifier` so we can reference classes by their string description
    /// and, if needed, constrain the match to a specific Core Animation layer subtype.
    private var ignoreClassesIdentifiers: Set<ClassIdentifier>

    /// This is a list of UIView subclasses that need to be redacted from screenshot
    ///
    /// This set is configured as `private(set)` to allow modification only from within this class,
    /// while still allowing read access from tests. Same semantics as `ignoreClassesIdentifiers`.
    private var redactClassesIdentifiers: Set<ClassIdentifier> {
        didSet {
            rebuildOptimizedLookups()
        }
    }

    /// Optimized lookup: class IDs that should be redacted without layer constraints
    private var unconstrainedRedactClasses: Set<ClassIdentifier> = []
    
    /// Optimized lookup: class IDs with layer constraints (includes both classId and layerId)
    private var constrainedRedactClasses: Set<ClassIdentifier> = []

    /// Initializes a new instance of the redaction process with the specified options.
    ///
    /// This initializer populates allow/deny lists for view types using `ExtendedClassIdentifier`,
    /// which lets us match by view class and, optionally, by layer class to disambiguate multi‑use
    /// view types (e.g. `SwiftUI._UIGraphicsView`).
    ///
    /// - parameter options: A `SentryRedactOptions` object that specifies the configuration.
    /// - If `options.maskAllText` is `true`, common UIKit text views and SwiftUI text drawing views are redacted.
    /// - If `options.maskAllImages` is `true`, UIKit/SwiftUI/Hybrid image views are redacted.
    /// - `options.unmaskViewTypes` contributes to the ignore list; `options.maskViewTypes` to the redact list.
    ///
    /// - note: On iOS, views such as `WKWebView` and `UIWebView` are always redacted, and controls like
    ///   `UISlider` and `UISwitch` are ignored by default.
    init(options: SentryRedactOptions) {
        var redactClasses = Set<ClassIdentifier>()

        if options.maskAllText {
            redactClasses.insert(ClassIdentifier(objcType: UILabel.self))
            redactClasses.insert(ClassIdentifier(objcType: UITextView.self))
            redactClasses.insert(ClassIdentifier(objcType: UITextField.self))

            // The following classes are used by React Native to display text.
            // We are including them here to avoid leaking text from RN apps with manually initialized sentry-cocoa.

            // Used by React Native to render short text
            redactClasses.insert(ClassIdentifier(classId: "RCTTextView"))

            // Used by React Native to render long text
            redactClasses.insert(ClassIdentifier(classId: "RCTParagraphComponentView"))

            // Used by SwiftUI to render text without UIKit, e.g. `Text("Hello World")`.
            // We include the class name without a layer filter because it is specifically
            // used to draw text glyphs in this context.
            redactClasses.insert(ClassIdentifier(classId: "SwiftUI.CGDrawingView"))

            // Used to render SwiftUI.Text on iOS versions prior to iOS 18
            redactClasses.insert(ClassIdentifier(classId: "_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView"))

        }
        
        if options.maskAllImages {
            redactClasses.insert(ClassIdentifier(objcType: UIImageView.self))

            // Used by SwiftUI.Image to display SFSymbols, e.g. `Image(systemName: "star.fill")`
            redactClasses.insert(ClassIdentifier(classId: "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView"))

            // Used by SwiftUI.Image to display images, e.g. `Image("my_image")`.
            // The same view class is also used for structural backgrounds. We differentiate by
            // requiring the backing layer to be `SwiftUI.ImageLayer` so we only redact the image case.
            redactClasses.insert(ClassIdentifier(classId: "SwiftUI._UIGraphicsView", layerId: "SwiftUI.ImageLayer"))

            // These classes are used by React Native to display images/vectors.
            // We are including them here to avoid leaking images from RN apps with manually initialized sentry-cocoa.

            // Used by React Native to display images
            redactClasses.insert(ClassIdentifier(classId: "RCTImageView"))
        }
        
#if os(iOS)
        redactClasses.insert(ClassIdentifier(objcType: PDFView.self))
        redactClasses.insert(ClassIdentifier(objcType: WKWebView.self))

        // If we try to use 'UIWebView.self' it will not compile for macCatalyst, but the class does exists.
        redactClasses.insert(ClassIdentifier(classId: "UIWebView"))

        // Used by:
        // - https://developer.apple.com/documentation/SafariServices/SFSafariViewController
        // - https://developer.apple.com/documentation/AuthenticationServices/ASWebAuthenticationSession
        redactClasses.insert(ClassIdentifier(classId: "SFSafariView"))

        // Used by:
        // - https://developer.apple.com/documentation/avkit/avplayerviewcontroller
        redactClasses.insert(ClassIdentifier(classId: "AVPlayerView"))

        // _UICollectionViewListLayoutSectionBackgroundColorDecorationView is a special case because it is
        // used by the SwiftUI.List view to display the background color.
        //
        // Its frame can be extremely large and extend well beyond the visible list bounds. Treating it as a
        // normal opaque background view would generate clip regions that suppress unrelated redaction boxes
        // (e.g. navigation bar content). To avoid this, we short-circuit traversal and add a single redact
        // region for the decoration view instead of clip-outs.
        redactClasses.insert(ClassIdentifier(classId: "_UICollectionViewListLayoutSectionBackgroundColorDecorationView"))

        // These classes are standard UIKit controls that are ignored by default.
        // The reason why exactly they are ignored is unknown.
        ignoreClassesIdentifiers = [
            ClassIdentifier(objcType: UISlider.self),
            ClassIdentifier(objcType: UISwitch.self)
        ]
#else
        ignoreClassesIdentifiers = []
#endif
        
        for type in options.unmaskedViewClasses {
            ignoreClassesIdentifiers.insert(ClassIdentifier(class: type))
        }
        
        for type in options.maskedViewClasses {
            redactClasses.insert(ClassIdentifier(class: type))
        }
        
        redactClassesIdentifiers = redactClasses
        
        // didSet doesn't run during initialization, so we need to manually build the optimization structures
        rebuildOptimizedLookups()
    }

    /// Rebuilds the optimized lookup structures from `redactClassesIdentifiers`.
    ///
    /// This method splits `redactClassesIdentifiers` into two sets for O(1) lookups:
    /// - `unconstrainedRedactClasses`: Classes without layer constraints
    /// - `constrainedRedactClasses`: Classes with specific layer constraints
    ///
    /// Called automatically by `didSet` when `redactClassesIdentifiers` is modified,
    /// and manually during initialization (since `didSet` doesn't run during init).
    private func rebuildOptimizedLookups() {
        unconstrainedRedactClasses.removeAll()
        constrainedRedactClasses.removeAll()
        
        for identifier in redactClassesIdentifiers {
            if identifier.layerId == nil {
                // No layer constraint - add to unconstrained set
                unconstrainedRedactClasses.insert(ClassIdentifier(classId: identifier.classId))
            } else {
                // Has layer constraint - add full identifier
                constrainedRedactClasses.insert(identifier)
            }
        }
    }

    /// Returns `true` if the provided class type is contained in the ignore list.
    ///
    /// - Note: This method does not check superclasses as we do in `containsRedactClass`, because it could unmask unwanted subclasses.
    ///         Example:
    ///
    ///     ```
    ///     class MyLabel: UILabel {}
    ///     class SuperSensitiveLabel: UILabel {}
    ///     ```
    ///
    ///     If we ignore `UILabel` it would also expose `MyLabel` and `SuperSensitiveLabel`, which might not be what the user wants.
    ///
    /// This compares by string description to avoid touching Objective‑C class objects directly.
    func containsIgnoreClass(_ class: AnyClass) -> Bool {
        return containsIgnoreClassId(ClassIdentifier(class: `class`))
    }

    /// Returns `true` if the provided class identifier is contained in the ignore list.
    private func containsIgnoreClassId(_ id: ClassIdentifier) -> Bool {
        /// Edge case: ``UITextField`` uses an internal type of ``UITextFieldLabel`` for the placeholder, which should also be ignored
        if id.classId == "UITextFieldLabel" {
            return ignoreClassesIdentifiers.contains(ClassIdentifier(classId: "UITextField"))
        }
        return ignoreClassesIdentifiers.contains(id)
    }

    /// Returns `true` if the view class (and, when required, the backing layer class) matches
    /// one of the configured redact identifiers.
    ///
    /// - Parameters:
    ///   - viewClass: Concrete runtime class of the `UIView` instance under inspection.
    ///   - layerClass: Concrete runtime class of the view's backing `CALayer`.
    ///
    /// Matching rules:
    /// - We traverse the view class hierarchy to honor base‑class entries (e.g. matching `UILabel` for subclasses).
    /// - If an identifier specifies a `layerId`, the layer’s type description must match as well.
    ///
    /// Examples:
    /// - A custom label `class MyTitleLabel: UILabel {}` will match because `UILabel` is in the redact set:
    ///   `containsRedactClass(viewClass: MyTitleLabel.self, layerClass: CALayer.self) == true`.
    /// - SwiftUI image drawing: `viewClass == SwiftUI._UIGraphicsView` and `layerClass == SwiftUI.ImageLayer`
    ///   will match because we register `("SwiftUI._UIGraphicsView", layerId: "SwiftUI.ImageLayer")`.
    /// - SwiftUI structural background: `viewClass == SwiftUI._UIGraphicsView` with a generic `CALayer`
    ///   will NOT match (no `ImageLayer`), so we don’t redact background fills.
    /// - `UIImageView` will match the class rule; the final decision is refined by `shouldRedact(imageView:)`.
    func containsRedactClass(viewClass: AnyClass, layerClass: AnyClass) -> Bool {
        var currentClass: AnyClass? = viewClass
        
        while let iteratorClass = currentClass {
            // Check if this class is in the unconstrained set (O(1) lookup)
            // This matches any layer type
            if unconstrainedRedactClasses.contains(ClassIdentifier(class: iteratorClass)) {
                return true
            }
            
            // Check if this class+layer combination is in the constrained set (O(1) lookup)
            // This only matches specific layer types
            if constrainedRedactClasses.contains(ClassIdentifier(class: iteratorClass, layer: layerClass)) {
                return true
            }
            
            currentClass = iteratorClass.superclass()
        }
        return false
    }
    
    /// Adds a class to the ignore list.
    func addIgnoreClass(_ ignoreClass: AnyClass) {
        ignoreClassesIdentifiers.insert(ClassIdentifier(class: ignoreClass))
    }
    
    /// Adds a class to the redact list.
    func addRedactClass(_ redactClass: AnyClass) {
        redactClassesIdentifiers.insert(ClassIdentifier(class: redactClass))
    }
    
    /// Adds multiple classes to the ignore list.
    func addIgnoreClasses(_ ignoreClasses: [AnyClass]) {
        ignoreClasses.forEach(addIgnoreClass(_:))
    }
    
    /// Adds multiple classes to the redact list.
    func addRedactClasses(_ redactClasses: [AnyClass]) {
        redactClasses.forEach(addRedactClass(_:))
    }

    /// Marks a container class whose direct children should be ignored (unmasked).
    func setIgnoreContainerClass(_ containerClass: AnyClass) {
        ignoreContainerClassIdentifier = ObjectIdentifier(containerClass)
    }

    /// Marks a container class whose subtree should be force‑redacted.
    ///
    /// Note: We also add the container class to the redact list so the container itself becomes a region.
    func setRedactContainerClass(_ containerClass: AnyClass) {
        let id = ObjectIdentifier(containerClass)
        redactContainerClassIdentifier = id
        redactClassesIdentifiers.insert(ClassIdentifier(class: containerClass))
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    func isIgnoreContainerClassTestOnly(_ containerClass: AnyClass) -> Bool {
        return isIgnoreContainerClass(containerClass)
    }

    func isRedactContainerClassTestOnly(_ containerClass: AnyClass) -> Bool {
        return isRedactContainerClass(containerClass)
    }
#endif

    /// Identifies and returns the regions within a given `UIView` that need to be redacted.
    ///
    /// - Parameter view: The root `UIView` for which redaction regions are to be calculated.
    /// - Returns: An array of `SentryRedactRegion` objects representing areas of the view (and its subviews)
    ///   that require redaction, based on visibility, opacity, and content (text or images).
    ///
    /// The method recursively traverses the view hierarchy, collecting redaction areas from the view and all
    /// its subviews. Each redaction area is calculated based on the view’s presentation layer, size, transform,
    /// and other attributes.
    ///
    /// The redaction process considers several key factors:
    /// 1. Text redaction when enabled by options.
    /// 2. Image redaction when enabled by options.
    /// 3. Opaque view handling: fully covering opaque views can clear previously collected regions.
    /// 4. Clip area creation to avoid over‑masking when a smaller opaque view blocks another view.
    ///
    /// The function returns the redaction regions in reverse order from what was found in the hierarchy,
    /// so clip regions are applied first before drawing a redact mask on lower views.
    func redactRegionsFor(view: UIView) -> [SentryRedactRegion] {
        var redactingRegions = [SentryRedactRegion]()

        self.mapRedactRegion(
            fromLayer: view.layer.presentation() ?? view.layer,
            relativeTo: nil,
            redacting: &redactingRegions,
            rootFrame: view.frame,
            transform: .identity
        )

        var swiftUIRedact = [SentryRedactRegion]()
        var otherRegions = [SentryRedactRegion]()
        
        for region in redactingRegions {
            if region.type == .redactSwiftUI {
                swiftUIRedact.append(region)
            } else {
                otherRegions.append(region)
            }
        }
        
        //The swiftUI type needs to appear first in the list so it always get masked
        return (otherRegions + swiftUIRedact).reversed()
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        return SentryRedactViewHelper.shouldUnmask(view) || containsIgnoreClassId(ClassIdentifier(class: type(of: view))) || shouldIgnoreParentContainer(view)
    }

    private func shouldIgnoreParentContainer(_ view: UIView) -> Bool {
        guard !isRedactContainerClass(type(of: view)), let parent = view.superview else { return false }
        return isIgnoreContainerClass(type(of: parent))
    }

    private func isIgnoreContainerClass(_ containerClass: AnyClass) -> Bool {
        guard ignoreContainerClassIdentifier != nil  else { return false }
        return ObjectIdentifier(containerClass) == ignoreContainerClassIdentifier
    }

    private func isRedactContainerClass(_ containerClass: AnyClass) -> Bool {
        guard redactContainerClassIdentifier != nil  else { return false }
        return ObjectIdentifier(containerClass) == redactContainerClassIdentifier
    }

    /// Determines whether a given view should be redacted based on configuration and heuristics.
    ///
    /// Order of checks:
    /// 1. Per‑instance override via `SentryRedactViewHelper.shouldMaskView`.
    /// 2. Class‑based membership in `redactClassesIdentifiers` (optionally constrained by layer type).
    /// 3. Special case handling for `UIImageView` (bundle image exemption).
    private func shouldRedact(view: UIView) -> Bool {
        // First we check if the view instance was marked to be masked
        if SentryRedactViewHelper.shouldMaskView(view) {
            return true
        }

        // Extract the view and layer types for checking
        let viewType = type(of: view)
        let layerType = type(of: view.layer)

        // Check if the view is supposed to be redacted
        guard containsRedactClass(viewClass: viewType, layerClass: layerType) else {
            return false
        }

        // We need to perform special handling for UIImageView
        if let imageView = view as? UIImageView {
            return shouldRedact(imageView: imageView)
        }

        return true
    }
    
    /// Special handling for `UIImageView` to avoid masking tiny gradient strips and
    /// bundle‑provided assets (e.g. SF Symbols or app assets), which are unlikely to contain PII.
    private func shouldRedact(imageView: UIImageView) -> Bool {
        // Checking the size is to avoid redacting gradient backgrounds that are usually
        // implemented as very thin repeating images.
        // The pixel size of `10` is an undocumented threshold and should be considered a magic number.
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else {
            return false
        }
        return image.imageAsset?.value(forKey: "_containingBundle") == nil
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func mapRedactRegion(fromLayer layer: CALayer, relativeTo parentLayer: CALayer?, redacting: inout [SentryRedactRegion], rootFrame: CGRect, transform: CGAffineTransform, forceRedact: Bool = false) {
        guard !redactClassesIdentifiers.isEmpty && !layer.isHidden && layer.opacity != 0 else {
            return
        }
        let newTransform = concatenateTranform(transform, from: layer, withParent: parentLayer)
        var enforceRedact = forceRedact

        if let view = layer.delegate as? UIView {
            // Check if the subtree should be ignored to avoid crashes with some special views.
            if isViewSubtreeIgnored(view) {
                // If a subtree is ignored, it should be fully redacted and we return early to prevent duplicates, unless the view was marked explicitly to be ignored (e.g. UISwitch).
                if !shouldIgnore(view: view) {
                    redacting.append(SentryRedactRegion(
                        size: layer.bounds.size,
                        transform: newTransform,
                        type: .redact,
                        color: self.color(for: view),
                        name: view.debugDescription
                    ))
                }
                return
            }

            let ignore = !forceRedact && shouldIgnore(view: view)
            let swiftUI = SentryRedactViewHelper.shouldRedactSwiftUI(view)
            let redact = forceRedact || shouldRedact(view: view) || swiftUI

            if !ignore && redact {
                redacting.append(SentryRedactRegion(
                    size: layer.bounds.size,
                    transform: newTransform,
                    type: swiftUI ? .redactSwiftUI : .redact,
                    color: self.color(for: view),
                    name: view.debugDescription
                ))

                guard !view.clipsToBounds else {
                    return
                }
                enforceRedact = true
            } else if isOpaque(view) {
                let finalViewFrame = CGRect(origin: .zero, size: layer.bounds.size).applying(newTransform)
                if isAxisAligned(newTransform) && finalViewFrame == rootFrame {
                    // Because the current view is covering everything we found so far we can clear `redacting` list
                    redacting.removeAll()
                } else {
                    redacting.append(SentryRedactRegion(
                        size: layer.bounds.size,
                        transform: newTransform,
                        type: .clipOut,
                        name: view.debugDescription
                    ))
                }
            }
        }

        // Traverse the sublayers to redact them if necessary
        guard let subLayers = layer.sublayers, subLayers.count > 0 else {
            return
        }
        let clipToBounds = layer.masksToBounds
        if clipToBounds {
            /// Because the order in which we process the redacted regions is reversed, we add the end of the clip region first.
            /// The beginning will be added after all the subviews have been mapped.
            redacting.append(SentryRedactRegion(
                size: layer.bounds.size,
                transform: newTransform,
                type: .clipEnd,
                name: layer.debugDescription
            ))
        }
        // Preserve Core Animation's sibling order when zPosition ties to mirror real render order.
        let sortedSubLayers = subLayers.enumerated().sorted { lhs, rhs in
            if lhs.element.zPosition == rhs.element.zPosition {
                return lhs.offset < rhs.offset
            }
            return lhs.element.zPosition < rhs.element.zPosition
        }
        for (_, subLayer) in sortedSubLayers {
            mapRedactRegion(
                fromLayer: subLayer,
                relativeTo: layer,
                redacting: &redacting,
                rootFrame: rootFrame,
                transform: newTransform,
                forceRedact: enforceRedact
            )
        }
        if clipToBounds {
            redacting.append(SentryRedactRegion(
                size: layer.bounds.size,
                transform: newTransform,
                type: .clipBegin,
                name: layer.debugDescription
            ))
        }
    }

    private func isViewSubtreeIgnored(_ view: UIView) -> Bool {
        // We intentionally avoid using `NSClassFromString` or directly referencing class objects here,
        // because both approaches can trigger the Objective-C `+initialize` method on the class.
        // This has side effects and can cause crashes, especially when performed off the main thread
        // or with UIKit classes that expect to be initialized on the main thread.
        //
        // Instead, we use the string description of the type (i.e., `type(of: view).description()`)
        // for comparison. This is a safer, more "Swifty" approach that avoids the pitfalls of
        // class initialization side effects.
        //
        // We have previously encountered related issues:
        // - In EmergeTools' snapshotting code where using `NSClassFromString` led to crashes [1]
        // - In Sentry's own SubClassFinder where storing or accessing class objects on a background thread caused crashes due to `+initialize` being called on UIKit classes [2]
        //
        // [1] https://github.com/EmergeTools/SnapshotPreviews/blob/main/Sources/SnapshotPreviewsCore/View%2BSnapshot.swift#L248
        // [2] https://github.com/getsentry/sentry-cocoa/blob/00d97404946a37e983eabb21cc64bd3d5d2cb474/Sources/Sentry/SentrySubClassFinder.m#L58-L84   
        let viewTypeId = type(of: view).description()
        
        if #available(iOS 26.0, *), viewTypeId == Self.cameraSwiftUIViewClassId.classId {
            // CameraUI.ChromeSwiftUIView is a special case because it contains layers which can not be iterated due to this error:
            //
            // Fatal error: Use of unimplemented initializer 'init(layer:)' for class 'CameraUI.ModeLoupeLayer'
            //
            // This crash only occurs when building with Xcode 16 for iOS 26, so we add a runtime check
            return true
        }

        #if os(iOS)
        // UISwitch uses UIImageView internally, which can be in the list of redacted views.
        // But UISwitch is in the list of ignored class identifiers by default, because it uses
        // non-sensitive images. Therefore we want to ignore the subtree of UISwitch, unless
        // it was removed from the list of ignored classes
        if viewTypeId == "UISwitch" && containsIgnoreClassId(ClassIdentifier(classId: viewTypeId)) {
            return true
        }
        #endif // os(iOS)
        
        return false
    }

    /// Gets a transform that represents the layer global position.
    private func concatenateTranform(_ transform: CGAffineTransform, from layer: CALayer, withParent parentLayer: CALayer?) -> CGAffineTransform {
        let size = layer.bounds.size
        let anchorPoint = CGPoint(x: size.width * layer.anchorPoint.x, y: size.height * layer.anchorPoint.y)
        let position = parentLayer?.convert(layer.position, to: nil) ?? layer.position
        
        var newTransform = transform
        newTransform.tx = position.x
        newTransform.ty = position.y
        newTransform = CATransform3DGetAffineTransform(layer.transform).concatenating(newTransform)
        return newTransform.translatedBy(x: -anchorPoint.x, y: -anchorPoint.y)
    }
    
    /// Whether the transform does not contain rotation or skew.
    private func isAxisAligned(_ transform: CGAffineTransform) -> Bool {
        // Rotation exists if b or c are not zero
        return transform.b == 0 && transform.c == 0
    }

    /// Returns a preferred color for the redact region.
    ///
    /// For labels we use the resolved `textColor` to produce a visually pleasing mask that
    /// roughly matches the original foreground. Other views default to nil and the renderer
    /// will compute an average color from the underlying pixels.
    private func color(for view: UIView) -> UIColor? {
        return (view as? UILabel)?.textColor.withAlphaComponent(1)
    }
    
    /// Indicates whether the view is opaque and will block other views behind it.
    ///
    /// A view is considered opaque if it completely covers and hides any content behind it.
    /// This is used to optimize redaction by clearing out regions that are fully covered.
    ///
    /// The method checks multiple properties because UIKit views can become transparent in several ways:
    /// - `view.alpha` (mapped to `layer.opacity`) can make the entire view semi-transparent
    /// - `view.backgroundColor` or `layer.backgroundColor` can have alpha components
    /// - Either the view or layer can explicitly set their `isOpaque` property to false
    ///
    /// ## Implementation Notes:
    /// - We use the presentation layer when available to get the actual rendered state during animations
    /// - We require BOTH the view and the layer to appear opaque (alpha == 1 and marked opaque)
    ///   to classify a view as opaque. This avoids false positives where only one side is configured,
    ///   which previously caused semi‑transparent overlays or partially configured views to clear
    ///   redactions behind them.
    /// - We use `SentryRedactViewHelper.shouldClipOut(view)` for views explicitly marked as opaque
    ///
    /// ## Bug Fix Context:
    /// This implementation fixes the issue where semi-transparent overlays (e.g., with `alpha = 0.2`)
    /// were incorrectly treated as opaque, causing text behind them to not be redacted.
    /// See: https://github.com/getsentry/sentry-cocoa/pull/6629#issuecomment-3479730690
    private func isOpaque(_ view: UIView) -> Bool {
        let layer = view.layer.presentation() ?? view.layer

        // Allow explicit override: if a view is marked to clip out, treat it as opaque
        if SentryRedactViewHelper.shouldClipOut(view) {
            return true
        }

        // First check: Ensure the layer opacity is 1.0
        // This catches views with `alpha < 1.0`, which are semi-transparent regardless of background color.
        // For example, a view with `alpha = 0.2` should never be considered opaque, even if it has
        // a solid background color, because the entire view (including the background) is semi-transparent.
        guard layer.opacity == 1 else {
            return false
        }

        // Second check: Verify the view has an opaque background color
        // We check the view's properties first because this is the most common pattern in UIKit.
        let isViewOpaque = view.isOpaque && view.backgroundColor != nil && (view.backgroundColor?.cgColor.alpha ?? 0) == 1

        // Third check: Verify the layer has an opaque background color
        // We also check the layer's properties because:
        // - Some views customize their CALayer directly without setting view.backgroundColor
        // - Libraries or custom views might override backgroundColor to return different values
        // - The layer's backgroundColor is the actual rendered property (view.backgroundColor is a convenience)
        let isLayerOpaque = layer.isOpaque && layer.backgroundColor != nil && (layer.backgroundColor?.alpha ?? 0) == 1

        // We REQUIRE BOTH: the view AND the layer must be opaque for the view to be treated as opaque.
        // This stricter rule prevents semi‑transparent overlays or partially configured backgrounds
        // (only view or only layer) from clearing previously collected redact regions.
        return isViewOpaque && isLayerOpaque
    }
}

#endif
#endif
// swiftlint:enable file_length type_body_length
