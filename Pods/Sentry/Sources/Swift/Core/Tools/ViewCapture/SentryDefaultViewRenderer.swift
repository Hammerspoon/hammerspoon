#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import UIKit

@objcMembers
@_spi(Private) public class SentryDefaultViewRenderer: NSObject, SentryViewRenderer {
    public func render(view: UIView) -> UIImage {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        return image
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
