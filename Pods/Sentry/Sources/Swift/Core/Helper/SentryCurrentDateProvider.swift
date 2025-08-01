import Foundation

/**
 * We need a protocol to expose SentryCurrentDateProvider to tests.
 * Mocking the previous private class from `SentryTestUtils` stopped working in Xcode 16.
*/
@objc
@_spi(Private) public protocol SentryCurrentDateProvider {
    func date() -> Date
    func timezoneOffset() -> Int
    func systemTime() -> UInt64
    func systemUptime() -> TimeInterval
}

@objcMembers
@_spi(Private) public class SentryDefaultCurrentDateProvider: NSObject, SentryCurrentDateProvider {
    public func date() -> Date {
        return Date()
    }
    
    public func timezoneOffset() -> Int {
        return TimeZone.current.secondsFromGMT()
    }
    
    /**
     * Returns the absolute timestamp, which has no defined reference point or unit
     * as it is platform dependent.
     */
    public func systemTime() -> UInt64 {
        Self.getAbsoluteTime()
    }
    
    public func systemUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    public static func getAbsoluteTime() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }
}
