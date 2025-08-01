import Foundation

#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

@objc
@_spi(Private) public class SwiftDescriptor: NSObject {
    
    @objc
    public static func getObjectClassName(_ object: AnyObject) -> String {
        return String(describing: type(of: object))
    }

    /// UIViewControllers aren't available on watchOS
#if canImport(UIKit) && !os(watchOS) && !SENTRY_NO_UIKIT
    @objc
    public static func getViewControllerClassName(_ object: UIViewController) -> String {
        if let object = object as? SentryUIViewControllerDescriptor {
            return object.sentryName
        }
        return getObjectClassName(object)
    }
#endif

    @objc
    public static func getSwiftErrorDescription(_ error: Error) -> String? {
        return String(describing: error)
    }
}
