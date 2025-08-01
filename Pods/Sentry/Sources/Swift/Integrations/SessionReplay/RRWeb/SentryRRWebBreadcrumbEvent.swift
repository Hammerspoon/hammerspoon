import Foundation

@_spi(Private) public final class SentryRRWebBreadcrumbEvent: SentryRRWebCustomEvent {
    public init(timestamp: Date, category: String, message: String? = nil, level: SentryLevel = .none, data: [String: Any]? = nil) {
        
        var payload: [String: Any] = ["type": "default", "category": category, "level": level.description, "timestamp": timestamp.timeIntervalSince1970 ]

        if let message = message {
            payload["message"] = message
        }
        
        if let data = data {
            payload["data"] = data
        }
        
        super.init(timestamp: timestamp, tag: "breadcrumb", payload: payload)
    }
}
