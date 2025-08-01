import Foundation

@objcMembers
@_spi(Private) public class SentryReplayRecording: NSObject {
    
    static let SentryReplayEncoding = "h264"
    static let SentryReplayContainer = "mp4"
    static let SentryReplayFrameRateType = "constant"
    
    let segmentId: Int
    let events: [any SentryRRWebEventProtocol]
    
    let height: Int
    let width: Int
    
    public convenience init(segmentId: Int, video: SentryVideoInfo, extraEvents: [any SentryRRWebEventProtocol]) {
        self.init(segmentId: segmentId, size: video.fileSize, start: video.start, duration: video.duration, frameCount: video.frameCount, frameRate: video.frameRate, height: video.height, width: video.width, extraEvents: extraEvents)
    }
    
    init(segmentId: Int, size: Int, start: Date, duration: TimeInterval, frameCount: Int, frameRate: Int, height: Int, width: Int, extraEvents: [any SentryRRWebEventProtocol]?) {
        self.segmentId = segmentId
        self.width = width
        self.height = height
        
        let meta = SentryRRWebMetaEvent(timestamp: start, height: height, width: width)
        let video = SentryRRWebVideoEvent(timestamp: start, segmentId: segmentId, size: size, duration: duration, encoding: SentryReplayRecording.SentryReplayEncoding, container: SentryReplayRecording.SentryReplayContainer, height: height, width: width, frameCount: frameCount, frameRateType: SentryReplayRecording.SentryReplayFrameRateType, frameRate: frameRate, left: 0, top: 0)
        self.events = [meta, video] + (extraEvents ?? [])
    }

    public func headerForReplayRecording() -> [String: Any] {
        return ["segment_id": segmentId]
    }

    public func serialize() -> [[String: Any]] {
        return events.map { $0.serialize() }
    }
}
