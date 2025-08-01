import Foundation

@objcMembers
@_spi(Private) public class SentryFramesDelayResult: NSObject {
    /// The frames delay for the passed time period. If frame delay can't be calculated this is -1.
    public let delayDuration: CFTimeInterval
    public let framesContributingToDelayCount: UInt

    public init(delayDuration: CFTimeInterval, framesContributingToDelayCount: UInt) {
        self.delayDuration = delayDuration
        self.framesContributingToDelayCount = framesContributingToDelayCount
    }
}
