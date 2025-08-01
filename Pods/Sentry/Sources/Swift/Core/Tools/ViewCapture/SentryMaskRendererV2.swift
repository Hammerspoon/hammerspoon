#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import UIKit

final class SentryMaskRendererV2: SentryDefaultMaskRenderer {
    override func maskScreenshot(screenshot image: UIImage, size: CGSize, masking: [SentryRedactRegion]) -> UIImage {
        // The `SentryDefaultMaskRenderer` is also using an display scale of 1, therefore we also use 1 here.
        // This could be evaluated in future iterations to view performance impact vs quality.
        let image = SentryGraphicsImageRenderer(size: size, scale: 1).image { context in
            // The experimental mask renderer only uses a different graphics renderer and can reuse the default masking logic.
            applyMasking(to: context, image: image, size: size, masking: masking)
        }
        return image
    }
}

extension SentryGraphicsImageRenderer.Context: SentryMaskRendererContext {}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
