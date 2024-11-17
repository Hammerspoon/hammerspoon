import Foundation

@objcMembers
class SentryRRWebCustomEvent: SentryRRWebEvent {
    let tag: String
    
    init(timestamp: Date, tag: String, payload: [String: Any]) {
        self.tag = tag
        super.init(type: .custom, timestamp: timestamp, data: ["tag": tag, "payload": payload])
    }
    
}
