import Foundation

@objc
protocol SentryANRTracker {
    @objc(addListener:)
    func add(listener: SentryANRTrackerDelegate)
    @objc(removeListener:)
    func remove(listener: SentryANRTrackerDelegate)
    
    /// Only used for tests.
    func clear()
}
