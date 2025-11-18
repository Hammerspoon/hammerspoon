import Foundation
import ObjectiveC.runtime

@objc @_spi(Private)
public final class SentryDefaultObjCRuntimeWrapper: NSObject, SentryObjCRuntimeWrapper {
    @_spi(Private)
    public func copyClassNamesForImage(_ image: UnsafePointer<CChar>, _ outCount: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<CChar>>? {
        return objc_copyClassNamesForImage(image, outCount)
    }
    
    @_spi(Private)
    public func classGetImageName(_ cls: AnyClass) -> UnsafePointer<CChar>? {
        return class_getImageName(cls)
    }
}
