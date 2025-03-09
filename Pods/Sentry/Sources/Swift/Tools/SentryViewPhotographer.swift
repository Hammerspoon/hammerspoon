#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import CoreGraphics
import Foundation
import UIKit

@objcMembers
class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    
    static let shared = SentryViewPhotographer()
    
    private let redactBuilder = UIRedactBuilder()
        
    func image(view: UIView, options: SentryRedactOptions, onComplete: @escaping ScreenshotCallback ) {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        
        let redact = redactBuilder.redactRegionsFor(view: view, options: options)
        let imageSize = view.bounds.size
        DispatchQueue.global().async {
            let screenshot = UIGraphicsImageRenderer(size: imageSize, format: .init(for: .init(displayScale: 1))).image { context in
                context.cgContext.interpolationQuality = .none
                image.draw(at: .zero)
                
                for region in redact {
                    (region.color ?? UIImageHelper.averageColor(of: context.currentImage, at: region.rect)).setFill()
                    context.fill(region.rect)
                }
            }
            onComplete(screenshot)
        }
    }
    
    @objc(addIgnoreClasses:)
    func addIgnoreClasses(classes: [AnyClass]) {
        redactBuilder.addIgnoreClasses(classes)
    }

    @objc(addRedactClasses:)
    func addRedactClasses(classes: [AnyClass]) {
        redactBuilder.addRedactClasses(classes)
    }
    
#if TEST || TESTCI
    func getRedactBuild() -> UIRedactBuilder {
        redactBuilder
    }
#endif
    
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
