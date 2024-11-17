#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import AVFoundation
import CoreGraphics
import Foundation
import UIKit

class SentryPixelBuffer {
    private var pixelBuffer: CVPixelBuffer?
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let size: CGSize
    private let pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor
    
    init?(size: CGSize, videoWriterInput: AVAssetWriterInput) {
        self.size = size
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        if status != kCVReturnSuccess {
            return nil
        }
        let bufferAttributes: [String: Any] = [
           String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32ARGB
        ]
        
        pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: bufferAttributes)
    }
    
    func append(image: UIImage, presentationTime: CMTime) -> Bool {
        guard let pixelBuffer = pixelBuffer else { return false }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)

        guard
            let cgimage = image.cgImage,
            let context = CGContext(
                data: pixelData,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: rgbColorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            ) else {
            return false
        }

        context.draw(cgimage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        return pixelBufferAdapter.append(pixelBuffer, withPresentationTime: presentationTime)
    }
}
#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
