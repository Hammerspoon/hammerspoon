#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import Foundation
import UIKit

final class UIImageHelper {
    private init() { }
    
    static func averageColor(of image: UIImage, at region: CGRect) -> UIColor {
        let scaledRegion = region.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))
        guard let croppedImage = image.cgImage?.cropping(to: scaledRegion), let colorSpace = croppedImage.colorSpace else {
            return .black
        }
        
        let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        guard let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return .black }
        context.interpolationQuality = .high
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let pixelBuffer = context.data else { return .black }
        
        let data = pixelBuffer.bindMemory(to: UInt8.self, capacity: 4)
        
        let blue = CGFloat(data[0]) / 255.0
        let green = CGFloat(data[1]) / 255.0
        let red = CGFloat(data[2]) / 255.0
        let alpha = CGFloat(data[3]) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

}

#endif
#endif
