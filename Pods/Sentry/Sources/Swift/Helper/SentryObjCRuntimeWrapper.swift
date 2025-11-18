import Foundation

@objc @_spi(Private)
public protocol SentryObjCRuntimeWrapper {
    @objc(copyClassNamesForImage:amount:)
    func copyClassNamesForImage(_ image: UnsafePointer<CChar>, _ outCount: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<CChar>>?
    @objc(class_getImageName:)
    func classGetImageName(_ cls: AnyClass) -> UnsafePointer<CChar>?
}
