import Foundation

@objcMembers
class SentryFramesDelayResult: NSObject {
    /// The frames delay for the passed time period. If frame delay can't be calculated this is -1.
    let delayDuration: CFTimeInterval
    let framesContributingToDelayCount: UInt

    init(delayDuration: CFTimeInterval, framesContributingToDelayCount: UInt) {
        self.delayDuration = delayDuration
        self.framesContributingToDelayCount = framesContributingToDelayCount
    }
}
