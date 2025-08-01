import Foundation

///
/// Use this protocol to customize the name used in the automatic
/// UIViewController performance tracker, view hierarchy, and breadcrumbs.
///
@objc
public protocol SentryUIViewControllerDescriptor: NSObjectProtocol {

    /// The custom name of the UIViewController
    /// that the Sentry SDK uses for transaction names, breadcrumbs, and
    /// view hierarchy.
    var sentryName: String { get }
}
