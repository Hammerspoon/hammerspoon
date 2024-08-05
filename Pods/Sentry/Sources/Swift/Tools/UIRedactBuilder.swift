#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import UIKit

struct RedactRegion {
    let rect: CGRect
    let color: UIColor?
    
    init(rect: CGRect, color: UIColor? = nil) {
        self.rect = rect
        self.color = color
    }
    
    func splitBySubtracting(region: CGRect) -> [RedactRegion] {
        guard rect.intersects(region) else { return [self] }
        guard !region.contains(rect) else { return [] }
        
        let intersectionRect = rect.intersection(region)
        var resultRegions: [CGRect] = []
        
        // Calculate the top region.
        resultRegions.append(CGRect(x: rect.minX,
                                    y: rect.minY,
                                    width: rect.width,
                                    height: intersectionRect.minY - rect.minY))
        
        // Calculate the bottom region.
        resultRegions.append(CGRect(x: rect.minX,
                                    y: intersectionRect.maxY,
                                    width: rect.width,
                                    height: rect.maxY - intersectionRect.maxY))
        
        // Calculate the left region.
        resultRegions.append(CGRect(x: rect.minX,
                                    y: max(rect.minY, intersectionRect.minY),
                                    width: intersectionRect.minX - rect.minX,
                                    height: min(intersectionRect.maxY, rect.maxY) - max(rect.minY, intersectionRect.minY)))
        
        // Calculate the right region.
        resultRegions.append(CGRect(x: intersectionRect.maxX,
                                    y: max(rect.minY, intersectionRect.minY),
                                    width: rect.maxX - intersectionRect.maxX,
                                    height: min(intersectionRect.maxY, rect.maxY) - max(rect.minY, intersectionRect.minY)))
        
        return resultRegions.filter { !$0.isEmpty }.map { RedactRegion(rect: $0, color: color) }
    }
}

class UIRedactBuilder {
    
    //This is a list of UIView subclasses that will be ignored during redact process
    var ignoreClasses: [AnyClass] 
    //This is a list of UIView subclasses that need to be redacted from screenshot
    var redactClasses: [AnyClass]
    
    init() {
        
        redactClasses = [ UILabel.self, UITextView.self, UITextField.self ] +
        //this classes are used by SwiftUI to display images.
        ["_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
            "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
            "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer"
        ].compactMap { NSClassFromString($0) }
#if os(iOS)
        ignoreClasses = [ UISlider.self, UISwitch.self ]
#else
        ignoreClasses = []
#endif
    }
    
    func redactRegionsFor(view: UIView, options: SentryRedactOptions?) -> [RedactRegion] {
        var redactingRegions = [RedactRegion]()
        
        self.mapRedactRegion(fromView: view,
                             to: view,
                             redacting: &redactingRegions,
                             area: view.frame,
                             redactText: options?.redactAllText ?? true,
                             redactImage: options?.redactAllImages ?? true)
        
        return redactingRegions
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        ignoreClasses.contains { view.isKind(of: $0) }
    }
    
    private func shouldRedact(view: UIView, redactText: Bool, redactImage: Bool) -> Bool {
        if redactImage, let imageView = view as? UIImageView {
            return shouldRedact(imageView: imageView)
        }
        return redactText && redactClasses.contains { view.isKind(of: $0) }
    }
    
    private func shouldRedact(imageView: UIImageView) -> Bool {
        // Checking the size is to avoid redact gradient background that
        // are usually small lines repeating
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else { return false }
        return image.imageAsset?.value(forKey: "_containingBundle") == nil
    }
    
    private func mapRedactRegion(fromView view: UIView, to: UIView, redacting: inout [RedactRegion], area: CGRect, redactText: Bool, redactImage: Bool) {
        let rectInWindow = view.convert(view.bounds, to: to)
        guard (redactImage || redactText) && area.intersects(rectInWindow) && !view.isHidden && view.alpha != 0 else { return }
        
        let ignore = shouldIgnore(view: view)
        let redact = shouldRedact(view: view, redactText: redactText, redactImage: redactImage)
        
        if !ignore && redact {
            redacting.append(RedactRegion(rect: rectInWindow, color: self.color(for: view)))
            return
        } else if hasBackground(view) {
            if rectInWindow == area {
                redacting.removeAll()
            } else {
                redacting = redacting.flatMap { $0.splitBySubtracting(region: rectInWindow) }
            }
        }
        
        if !ignore {
            for subview in view.subviews {
                mapRedactRegion(fromView: subview, to: to, redacting: &redacting, area: area, redactText: redactText, redactImage: redactImage)
            }
        }
    }
    
    private func color(for view: UIView) -> UIColor? {
        return (view as? UILabel)?.textColor
    }
    
    private func hasBackground(_ view: UIView) -> Bool {
        //Anything with an alpha greater than 0.9 is opaque enough that it's impossible to see anything behind it.
        return view.backgroundColor != nil && (view.backgroundColor?.cgColor.alpha ?? 0) > 0.9
    }
}

#endif
#endif
