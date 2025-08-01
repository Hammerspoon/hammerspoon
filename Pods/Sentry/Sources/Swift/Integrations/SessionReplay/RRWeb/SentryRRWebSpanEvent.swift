import Foundation

@objc @_spi(Private) public class SentryRRWebSpanEvent: SentryRRWebCustomEvent {
    
    public init(timestamp: Date, endTimestamp: Date, operation: String, description: String, data: [String: Any]) {
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
