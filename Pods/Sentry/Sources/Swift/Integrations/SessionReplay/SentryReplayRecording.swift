@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryReplayRecording: NSObject {
    
    static let SentryReplayEncoding = "h264"
    static let SentryReplayContainer = "mp4"
    static let SentryReplayFrameRateType = "constant"
    
    let segmentId: Int

    let events: [any SentryRRWebEventProtocol]
    
    init(segmentId: Int, size: Int, start: Date, duration: TimeInterval, frameCount: Int, frameRate: Int, height: Int, width: Int, extraEvents: [any SentryRRWebEventProtocol]?) {
        self.segmentId = segmentId
        
        let meta = SentryRRWebMetaEvent(timestamp: start, height: height, width: width)
        let video = SentryRRWebVideoEvent(timestamp: start, segmentId: segmentId, size: size, duration: duration, encoding: SentryReplayRecording.SentryReplayEncoding, container: SentryReplayRecording.SentryReplayContainer, height: height, width: width, frameCount: frameCount, frameRateType: SentryReplayRecording.SentryReplayFrameRateType, frameRate: frameRate, left: 0, top: 0)
        self.events = [meta, video] + (extraEvents ?? [])
    }

    func headerForReplayRecording() -> [String: Any] {
        return ["segment_id": segmentId]
    }

    func serialize() -> [[String: Any]] {
        return events.map { $0.serialize() }
    }
}
