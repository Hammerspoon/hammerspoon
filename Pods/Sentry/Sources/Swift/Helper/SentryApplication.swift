#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

@objc @_spi(Private) public protocol SentryApplication {
    
    // This can only be accessed on the main thread
    var mainThread_isActive: Bool { get }

    #if !os(macOS) && !os(watchOS) && !SENTRY_NO_UIKIT
    
    /**
     * Returns the application state available at @c UIApplication.sharedApplication.applicationState
     * Must be called on the main thread.
     */
    var unsafeApplicationState: UIApplication.State { get }

/**
 * All windows connected to scenes.
 */
    func getWindows() -> [UIWindow]?
    
    @available(iOS 13.0, tvOS 13.0, *)
    var connectedScenes: Set<UIScene> { get }

    var delegate: UIApplicationDelegate? { get }

/**
 * Use @c [SentryUIApplication relevantViewControllers] and convert the
 * result to a string array with the class name of each view controller.
 */
    func relevantViewControllersNames() -> [String]?
    #endif // canImport(UIKit) && !SENTRY_NO_UIKIT
}
