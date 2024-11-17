@_implementationOnly import _SentryPrivate
import Foundation

@objc
protocol SentrySessionListener: NSObjectProtocol {
    func sentrySessionEnded(_ session: SentrySession)
    func sentrySessionStarted(_ session: SentrySession)
}
