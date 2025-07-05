#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import UIKit

protocol SentryMaskRenderer {
    func maskScreenshot(screenshot image: UIImage, size: CGSize, masking: [SentryRedactRegion]) -> UIImage
}

protocol SentryMaskRendererContext {
    var cgContext: CGContext { get }
    var currentImage: UIImage { get }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
