#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import UIKit

/**
 * Class similar to the ``UIKit/UIGraphicsImageRenderer`` class, but optimized for Sentry.
 *
 * We introduced this class, because the ``UIGraphicsImageRenderer`` caused performance issues due to internal caching mechanisms mentioned in the
 * [Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uigraphicsimagerenderer) in the last paragraph of
 * the section _Overview_:
 *
 * > An image renderer keeps a cache of Core Graphics contexts, so reusing the same renderer can be more efficient than creating new renderers.
 *
 * During testing we noticed a significant performance improvement by creating the bitmap context directly using ``CoreGraphics/CGContext``.
 */
final class SentryGraphicsImageRenderer {
    struct Context {
        let cgContext: CGContext
        let scale: CGFloat

        /// Converts the current context into an image.
        ///
        /// - Returns: The image representation of the current context.
        /// - Remark: To reduce error-handling and potential issues, the image is always returned but can be empty.
        var currentImage: UIImage {
            guard let cgImage = cgContext.makeImage() else {
                SentrySDKLog.fatal("Unable to create image from graphics context")
                return UIImage()
            }
            return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        }
    }

    let size: CGSize
    let scale: CGFloat

    init(size: CGSize, scale: CGFloat) {
        self.size = size
        self.scale = scale
    }

    func image(actions: (Context) -> Void) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let pixelsPerRow = Int(size.width * scale)
        let pixelsPerColumn = Int(size.height * scale)
        let bytesPerPixel = 4 // 4 bytes for RGBA
        let bytesPerRow = bytesPerPixel * pixelsPerRow
        let bitsPerComponent = 8 // 8 bits for each of RGB component

        // Allocate memory for raw image data and initializes every byte in the allocated memory to 0.
        guard let rawData = calloc(pixelsPerColumn * bytesPerRow, MemoryLayout<UInt8>.size) else {
            SentrySDKLog.error("Unable to allocate memory for image data")
            return UIImage()
        }
        defer {
            free(rawData) // Release the memory when done
        }

        guard let context = CGContext(
            data: rawData,
            width: pixelsPerRow,
            height: pixelsPerColumn,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            SentrySDKLog.error("Unable to create context")
            return UIImage()
        }

        // UIKit coordinate system is flipped, so we need to shift and scale the context
        // to match the CoreGraphics coordinate system.
        context.translateBy(x: 0, y: size.height * scale)
        context.scaleBy(x: scale, y: -1 * scale)

        // Pushing context will make the context the current main context
        // and all the drawing operations will be performed on this context.
        // This is necessary for the view to be drawn on the context.
        // After drawing the view, we need to pop the context to make the original
        // context the current main context.
        UIGraphicsPushContext(context)
        let rendererContext = Context(cgContext: context, scale: scale)
        actions(rendererContext)
        UIGraphicsPopContext()

        return rendererContext.currentImage
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
