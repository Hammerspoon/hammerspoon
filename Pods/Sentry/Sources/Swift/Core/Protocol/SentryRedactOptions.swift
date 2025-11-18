import Foundation

@objc
public protocol SentryRedactOptions {
    var maskAllText: Bool { get }
    var maskAllImages: Bool { get }
    var maskedViewClasses: [AnyClass] { get }
    var unmaskedViewClasses: [AnyClass] { get }
}

@objcMembers
@_spi(Private) public final class SentryRedactDefaultOptions: NSObject, SentryRedactOptions {
    public var maskAllText: Bool = true
    public var maskAllImages: Bool = true
    public var maskedViewClasses: [AnyClass] = []
    public var unmaskedViewClasses: [AnyClass] = []
}
