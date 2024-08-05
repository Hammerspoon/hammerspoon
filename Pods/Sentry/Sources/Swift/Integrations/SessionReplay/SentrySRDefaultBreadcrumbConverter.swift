@_implementationOnly import _SentryPrivate
import Foundation

@objc
protocol SentryReplayBreadcrumbConverter: NSObjectProtocol {
    func convert(from breadcrumb: Breadcrumb) -> SentryRRWebEventProtocol?
}

@objcMembers
class SentrySRDefaultBreadcrumbConverter: NSObject, SentryReplayBreadcrumbConverter {
    
    private let supportedNetworkData = Set<String>([
        "status_code",
        "method",
        "response_body_size",
        "request_body_size",
        "http.query",
        "http.fragment"]
    )
    
    /**
     * This function will convert the SDK breadcrumbs to session replay breadcrumbs in a format that the front-end understands.
     * Any deviation in the information will cause the breadcrumb or the information itself to be discarded
     * in order to avoid unknown behavior in the front-end.
     */
    func convert(from breadcrumb: Breadcrumb) -> SentryRRWebEventProtocol? {
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
        } else if let position = breadcrumb.data?["position"] as? String, breadcrumb.category == "device.orientation" {
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
        guard let timestamp = breadcrumb.timestamp,
              let description = breadcrumb.data?["url"] as? String,
              let startTimestamp = breadcrumb.data?["request_start"] as? Date
        else { return nil }
        var data = [String: Any]()
        
        breadcrumb.data?.forEach({ (key, value) in
            guard supportedNetworkData.contains(key) else { return }
            let newKey = key.replacingOccurrences(of: "http.", with: "")
            data[newKey.snakeToCamelCase()] = value
        })
        
        //We dont have end of the request in the breadcrumb.
        return SentryRRWebSpanEvent(timestamp: startTimestamp, endTimestamp: timestamp, operation: "resource.http", description: description, data: data)
    }
    
    private func getLevel(breadcrumb: Breadcrumb) -> SentryLevel {
        return SentryLevel(rawValue: SentryLevelHelper.breadcrumbLevel(breadcrumb)) ?? .none
    }
}
