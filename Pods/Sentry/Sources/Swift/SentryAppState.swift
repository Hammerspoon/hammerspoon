@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers @_spi(Private) public class SentryAppState: NSObject, SentrySerializable {
    
    public private(set) var releaseName: String?
    public private(set) var osVersion: String
    public private(set) var vendorId: String
    public private(set) var isDebugging: Bool
    
    /// The boot time of the system rounded down to seconds. As the precision of the serialization is
    /// only milliseconds and a precision of seconds is enough we round down to seconds. With this we
    /// avoid getting different dates before and after serialization.
    ///
    /// - warning: We must not send this information off device because Apple forbids that.
    /// We are allowed send the amount of time that has elapsed between events that occurred within the
    /// app though. For more information see
    /// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api#4278394.
    public private(set) var systemBootTimestamp: Date
    public var isActive: Bool
    public var wasTerminated: Bool
    public var isANROngoing: Bool
    public var isSDKRunning: Bool
    
    public init(releaseName: String?, osVersion: String, vendorId: String, isDebugging: Bool, systemBootTimestamp: Date) {
        self.releaseName = releaseName
        self.osVersion = osVersion
        self.vendorId = vendorId
        self.isDebugging = isDebugging
        
        // Round down to seconds as the precision of the serialization of the date is only
        // milliseconds. With this we avoid getting different dates before and after serialization.
        let interval = round(systemBootTimestamp.timeIntervalSince1970)
        self.systemBootTimestamp = Date(timeIntervalSince1970: interval)
        
        self.isActive = false
        self.wasTerminated = false
        self.isANROngoing = false
        self.isSDKRunning = true
        
        super.init()
    }
    
    // swiftlint:disable cyclomatic_complexity
    @objc(initWithJSONObject:)
    public init?(jsonObject: [String: Any]) {
        // Validate and extract releaseName
        if let releaseName = jsonObject["release_name"] {
            if !(releaseName is String) {
                return nil
            }
            self.releaseName = releaseName as? String
        } else {
            self.releaseName = nil
        }
        
        // Validate and extract osVersion
        guard let osVersion = jsonObject["os_version"] as? String else {
            return nil
        }
        self.osVersion = osVersion
        
        // Validate and extract vendorId
        guard let vendorId = jsonObject["vendor_id"] as? String else {
            return nil
        }
        self.vendorId = vendorId
        
        // Validate and extract isDebugging
        guard let isDebugging = jsonObject["is_debugging"] as? Bool else {
            return nil
        }
        self.isDebugging = isDebugging
        
        // Validate and extract systemBootTimestamp
        guard let systemBoot = jsonObject["system_boot_timestamp"] as? String else {
            return nil
        }
        guard let systemBootTimestamp = sentry_fromIso8601String(systemBoot) else {
            return nil
        }
        self.systemBootTimestamp = systemBootTimestamp
        
        // Validate and extract isActive
        guard let isActive = jsonObject["is_active"] as? Bool else {
            return nil
        }
        self.isActive = isActive
        
        // Validate and extract wasTerminated
        guard let wasTerminated = jsonObject["was_terminated"] as? Bool else {
            return nil
        }
        self.wasTerminated = wasTerminated
        
        // Validate and extract isANROngoing
        guard let isANROngoing = jsonObject["is_anr_ongoing"] as? Bool else {
            return nil
        }
        self.isANROngoing = isANROngoing
        
        // Validate and extract isSDKRunning
        if let isSDKRunning = jsonObject["is_sdk_running"] as? Bool {
            self.isSDKRunning = isSDKRunning
        } else {
            // This property was added later so instead of returning nil,
            // we're setting it to the default value.
            self.isSDKRunning = true
        }
        
        super.init()
    }
    // swiftlint:enable cyclomatic_complexity
    
    @objc public func serialize() -> [String: Any] {
        var data: [String: Any] = [:]
        
        if let releaseName = self.releaseName {
            data["release_name"] = releaseName
        }
        data["os_version"] = self.osVersion
        data["vendor_id"] = self.vendorId
        data["is_debugging"] = NSNumber(value: self.isDebugging)
        data["system_boot_timestamp"] = sentry_toIso8601String(self.systemBootTimestamp)
        data["is_active"] = NSNumber(value: self.isActive)
        data["was_terminated"] = NSNumber(value: self.wasTerminated)
        data["is_anr_ongoing"] = NSNumber(value: self.isANROngoing)
        data["is_sdk_running"] = NSNumber(value: self.isSDKRunning)
        
        return data
    }
} 
