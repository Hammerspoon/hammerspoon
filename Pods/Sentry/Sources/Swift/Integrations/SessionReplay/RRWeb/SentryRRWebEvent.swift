@_implementationOnly import _SentryPrivate
import Foundation

@objc
enum SentryRRWebEventType: Int {
    case none = 0
    case touch = 3
    case meta = 4
    case custom = 5
}

@objc(SentryRRWebEvent)
protocol SentryRRWebEventProtocol: SentrySerializable {
}

@objcMembers
class SentryRRWebEvent: NSObject, SentryRRWebEventProtocol {
    let type: SentryRRWebEventType
    let timestamp: Date
    let data: [String: Any]?
    
    init(type: SentryRRWebEventType, timestamp: Date, data: [String: Any]?) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
    
    func serialize() -> [String: Any] {
        var result: [String: Any] = [
            "type": type.rawValue,
            "timestamp": SentryDateUtil.millisecondsSince1970(timestamp)
        ]
        
        if let data = data {
            result["data"] = data
        }
        
        return result
    }
}
