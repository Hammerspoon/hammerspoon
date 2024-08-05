@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryRRWebVideoEvent: SentryRRWebCustomEvent {
    init(timestamp: Date, segmentId: Int, size: Int, duration: TimeInterval, encoding: String, container: String, height: Int, width: Int, frameCount: Int, frameRateType: String, frameRate: Int, left: Int, top: Int) {
        
        super.init(timestamp: timestamp, tag: "video", payload: [
            "timestamp": timestamp.timeIntervalSince1970,
            "segmentId": segmentId,
            "size": size,
            "duration": Int(duration * 1_000),
            "encoding": encoding,
            "container": container,
            "height": height,
            "width": width,
            "frameCount": frameCount,
            "frameRateType": frameRateType,
            "frameRate": frameRate,
            "left": left,
            "top": top
        ])
    }
}
