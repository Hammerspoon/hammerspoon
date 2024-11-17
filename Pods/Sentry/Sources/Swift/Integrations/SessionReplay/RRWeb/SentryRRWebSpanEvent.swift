@_implementationOnly import _SentryPrivate
import Foundation

@objc class SentryRRWebSpanEvent: SentryRRWebCustomEvent {
    
    init(timestamp: Date, endTimestamp: Date, operation: String, description: String, data: [String: Any]) {
        super.init(timestamp: timestamp, tag: "performanceSpan", payload:
                    [
                        "op": operation,
                        "description": description,
                        "startTimestamp": timestamp.timeIntervalSince1970,
                        "endTimestamp": endTimestamp.timeIntervalSince1970,
                        "data": data
                    ]
        )
    }
}
