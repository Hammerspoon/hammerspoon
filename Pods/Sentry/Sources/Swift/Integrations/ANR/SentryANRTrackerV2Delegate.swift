import Foundation

@objc
protocol SentryANRTrackerV2Delegate {
    func anrDetected(type: SentryANRType)
    func anrStopped()
}

@objc
enum SentryANRType: Int {
    case fullyBlocking
    case nonFullyBlocking
}
