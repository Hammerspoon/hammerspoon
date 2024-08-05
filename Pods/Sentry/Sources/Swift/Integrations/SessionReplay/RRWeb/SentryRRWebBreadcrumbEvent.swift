@_implementationOnly import _SentryPrivate
import Foundation

class SentryRRWebBreadcrumbEvent: SentryRRWebCustomEvent {
    init(timestamp: Date, category: String, message: String? = nil, level: SentryLevel = .none, data: [String: Any]? = nil) {
        
        var payload: [String: Any] = ["type": "default", "category": category, "level": SentryLevelHelper.getNameFor(level.rawValue), "timestamp": timestamp.timeIntervalSince1970 ]

        if let message = message {
            payload["message"] = message
        }
        
        if let data = data {
            payload["data"] = data
        }
        
        super.init(timestamp: timestamp, tag: "breadcrumb", payload: payload)
    }
}
