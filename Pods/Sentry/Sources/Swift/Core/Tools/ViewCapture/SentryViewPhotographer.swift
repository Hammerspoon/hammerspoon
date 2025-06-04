#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import CoreGraphics
import Foundation
import UIKit

@objcMembers
class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    private let redactBuilder: UIRedactBuilder
    private let maskRenderer: SentryMaskRenderer
    private let dispatchQueue = SentryDispatchQueueWrapper()

    var renderer: SentryViewRenderer

    /// Creates a view photographer used to convert a view hierarchy to an image.
    ///
    /// - Parameters:
    ///   - renderer: Implementation of the view renderer.
    ///   - redactOptions: Options provided to redact sensitive information.
    ///   - enableMaskRendererV2: Flag to enable experimental view renderer.
    /// - Note: The option `enableMaskRendererV2` is an internal flag, which is not part of the public API.
    ///         Therefore, it is not part of the the `redactOptions` parameter, to not further expose it.
    init(
        renderer: SentryViewRenderer,
        redactOptions: SentryRedactOptions,
        enableMaskRendererV2: Bool
    ) {
        self.renderer = renderer
        self.maskRenderer = enableMaskRendererV2 ? SentryMaskRendererV2() : SentryDefaultMaskRenderer()
        redactBuilder = UIRedactBuilder(options: redactOptions)
        super.init()
    }

    func image(view: UIView, onComplete: @escaping ScreenshotCallback) {
        let viewSize = view.bounds.size
        let redact = redactBuilder.redactRegionsFor(view: view)
        // The render method is synchronous and must be called on the main thread.
        // This is because the render method accesses the view hierarchy which is managed from the main thread.
        let renderedScreenshot = renderer.render(view: view)

        dispatchQueue.dispatchAsync { [maskRenderer] in
            // The mask renderer does not need to be on the main thread.
            // Moving it to a background thread to avoid blocking the main thread, therefore reducing the performance
            // impact/lag of the user interface.
            let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redact)
            onComplete(maskedScreenshot)
        }
    }

    func image(view: UIView) -> UIImage {
        let viewSize = view.bounds.size
        let redact = redactBuilder.redactRegionsFor(view: view)
        let renderedScreenshot = renderer.render(view: view)
        let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redact)

        return maskedScreenshot
    }

    @objc(addIgnoreClasses:)
    func addIgnoreClasses(classes: [AnyClass]) {
        redactBuilder.addIgnoreClasses(classes)
    }

    @objc(addRedactClasses:)
    func addRedactClasses(classes: [AnyClass]) {
        redactBuilder.addRedactClasses(classes)
    }

    @objc(setIgnoreContainerClass:)
    func setIgnoreContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setIgnoreContainerClass(containerClass)
    }

    @objc(setRedactContainerClass:)
    func setRedactContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setRedactContainerClass(containerClass)
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    func getRedactBuild() -> UIRedactBuilder {
        redactBuilder
    }
#endif
    
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
