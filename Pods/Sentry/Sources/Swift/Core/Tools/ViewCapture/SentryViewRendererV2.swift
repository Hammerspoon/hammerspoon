#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import UIKit

@objcMembers
@_spi(Private) public class SentryViewRendererV2: NSObject, SentryViewRenderer {
    let enableFastViewRendering: Bool

    public init(enableFastViewRendering: Bool) {
        self.enableFastViewRendering = enableFastViewRendering
    }

    public func render(view: UIView) -> UIImage {
        let scale = (view as? UIWindow ?? view.window)?.screen.scale ?? 1
        let image = SentryGraphicsImageRenderer(size: view.bounds.size, scale: scale).image { context in
            if enableFastViewRendering {
                view.layer.draw(in: context.cgContext)
            } else {
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            }
        }
        return image
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
