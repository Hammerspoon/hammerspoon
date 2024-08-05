import Foundation

@objcMembers
class SentryRRWebMetaEvent: SentryRRWebEvent {
    init(timestamp: Date, height: Int, width: Int) {
        super.init(type: .meta, timestamp: timestamp, data: ["href": "", "height": height, "width": width])
    }
}
