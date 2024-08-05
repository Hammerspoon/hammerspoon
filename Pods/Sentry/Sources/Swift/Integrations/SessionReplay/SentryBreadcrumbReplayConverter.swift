@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryBreadcrumbReplayConverter: NSObject {
    
    private let supportedNetworkData = Set<String>([
        "status_code",
        "method",
        "response_content_length",
        "request_content_length",
        "http.query",
        "http.fragment"]
    )
    
    func replayBreadcrumbs(from breadcrumbs: [Breadcrumb]) -> [SentryRRWebEvent] {
        breadcrumbs.compactMap { replayBreadcrumb(from: $0) }
    }
    
    //Convert breadcrumb information into something
    //replay front understands
    private func replayBreadcrumb(from breadcrumb: Breadcrumb) -> SentryRRWebEvent? {
        guard let timestamp = breadcrumb.timestamp else { return nil }
        if breadcrumb.category == "http" {
            return networkSpan(breadcrumb)
        } else if breadcrumb.type == "navigation" {
            return navigationBreadcrumb(breadcrumb)
        } else if breadcrumb.category == "touch" {
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "ui.tap", message: breadcrumb.message)
        } else if breadcrumb.type == "connectivity" && breadcrumb.category == "device.connectivity" {
            guard let networkType = breadcrumb.data?["connectivity"] as? String, !networkType.isEmpty  else { return nil }
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "device.connectivity", data: ["state": networkType])
        } else if let action = breadcrumb.data?["action"] as? String, action == "BATTERY_STATE_CHANGE" {
            var data = breadcrumb.data?.filter({ item in item.key == "level" || item.key == "plugged" }) ?? [:]
            
            data["charging"] = data["plugged"]
            data["plugged"] = nil
            
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp,
                                              category: "device.battery",
                                              data: data)
        }
        
        let level = getLevel(breadcrumb: breadcrumb)
        return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: breadcrumb.category, message: breadcrumb.message, level: level, data: breadcrumb.data)
    }
    
    private func navigationBreadcrumb(_ breadcrumb: Breadcrumb) -> SentryRRWebBreadcrumbEvent? {
        guard let timestamp = breadcrumb.timestamp else { return nil }
        
        if breadcrumb.category == "app.lifecycle" {
            guard let state = breadcrumb.data?["state"] else { return nil }
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "app.\(state)")
        } else if let position = breadcrumb.data?["position"] as? String, breadcrumb.category == "device.orientation" && (position == "landscape" || position == "portrait") {
            return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "device.orientation", data: ["position": position])
        } else {
            if let to = breadcrumb.data?["screen"] as? String {
                return SentryRRWebBreadcrumbEvent(timestamp: timestamp, category: "navigation", message: to, data: ["to": to])
            } else {
                return nil
            }
        }
    }
    
    private func networkSpan(_ breadcrumb: Breadcrumb) -> SentryRRWebSpanEvent? {
        guard let timestamp = breadcrumb.timestamp, let description = breadcrumb.data?["url"] as? String else { return nil }
        var data = [String: Any]()
        
        breadcrumb.data?.forEach({
            guard supportedNetworkData.contains($0.key) else { return }
            let newKey = $0.key == "response_body_size" ? "bodySize" : $0.key.replacingOccurrences(of: "http.", with: "")
            data[newKey.snakeToCamelCase()] = $0.value
        })
        
        //We dont have end of the request in the breadcrumb.
        return SentryRRWebSpanEvent(timestamp: timestamp, endTimestamp: timestamp, operation: "resource.http", description: description, data: data)
    }
    
    private  func getLevel(breadcrumb: Breadcrumb) -> SentryLevel {
        return SentryLevel(rawValue: SentryLevelHelper.breadcrumbLevel(breadcrumb)) ?? .none
        
    }
}
