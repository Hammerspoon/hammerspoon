import Foundation

@objc
public protocol SentryRedactOptions {
    var maskAllText: Bool { get }
    var maskAllImages: Bool { get }
    var maskedViewClasses: [AnyClass] { get }
    var unmaskedViewClasses: [AnyClass] { get }
}

@objcMembers
final class SentryRedactDefaultOptions: NSObject, SentryRedactOptions {
    var maskAllText: Bool = true
    var maskAllImages: Bool = true
    var maskedViewClasses: [AnyClass] = []
    var unmaskedViewClasses: [AnyClass] = []
}
