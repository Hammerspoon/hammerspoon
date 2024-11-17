@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers class SentryCurrentDateProvider: NSObject {
    
    func date() -> Date {
        return Date()
    }

    func timezoneOffset() -> Int {
        return TimeZone.current.secondsFromGMT()
    }

    func systemTime() -> UInt64 {
        getAbsoluteTime()
    }
    
    func systemUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
