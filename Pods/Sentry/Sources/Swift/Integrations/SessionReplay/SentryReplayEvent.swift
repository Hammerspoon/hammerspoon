@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryReplayEvent: Event {
    
    // Start time of the replay segment
    public let replayStartTimestamp: Date
    
    // The Type of the replay
    public let replayType: SentryReplayType
    
    /**
     * Number of the segment in the replay.
     * This is an incremental number
     */
    public let segmentId: Int
 
    /**
     * This will be used to store the name of the screens
     * that appear during the duration of the replay segment.
     */
    public var urls: [String]?

    public init(eventId: SentryId, replayStartTimestamp: Date, replayType: SentryReplayType, segmentId: Int) {
        self.replayStartTimestamp = replayStartTimestamp
        self.replayType = replayType
        self.segmentId = segmentId
        
        super.init()
        SentryEventSwiftHelper.setEventIdString(eventId.sentryIdString, event: self)
        self.type = "replay_video"
    }
    
    required convenience init() {
        fatalError("init() has not been implemented")
    }
    
    public override func serialize() -> [String: Any] {
        var result = super.serialize()
        result["urls"] = urls
        result["replay_start_timestamp"] = replayStartTimestamp.timeIntervalSince1970
        result["replay_id"] = SentryEventSwiftHelper.getEventIdString(self)
        result["segment_id"] = segmentId
        result["replay_type"] = replayType.toString()
        return result
    }
}
