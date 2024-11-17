@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryReplayEvent: Event {
    
    // Start time of the replay segment
    let replayStartTimestamp: Date
    
    // The Type of the replay
    let replayType: SentryReplayType
    
    /**
     * Number of the segment in the replay.
     * This is an incremental number
     */
    let segmentId: Int
 
    /**
     * This will be used to store the name of the screens
     * that appear during the duration of the replay segment.
     */
    var urls: [String]?
    
    init(eventId: SentryId, replayStartTimestamp: Date, replayType: SentryReplayType, segmentId: Int) {
        self.replayStartTimestamp = replayStartTimestamp
        self.replayType = replayType
        self.segmentId = segmentId
        
        super.init()
        self.eventId = eventId
        self.type = "replay_video"
    }
    
    required convenience init() {
        fatalError("init() has not been implemented")
    }
    
    override func serialize() -> [String: Any] {
        var result = super.serialize()
        result["urls"] = urls
        result["replay_start_timestamp"] = replayStartTimestamp.timeIntervalSince1970
        result["replay_id"] = eventId.sentryIdString
        result["segment_id"] = segmentId
        result["replay_type"] = replayType.toString()
        return result
    }
}
