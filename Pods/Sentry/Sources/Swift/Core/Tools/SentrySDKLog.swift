import Foundation

typealias SentryLogOutput = ((String) -> Void)

/// A note on the thread safety:
/// The methods configure and log don't use synchronization mechanisms, meaning they aren't strictly speaking thread-safe.
/// Still, you can use log from multiple threads. The problem is that when you call configure while
/// calling log from multiple threads, you experience a race condition. It can take a bit until all
/// threads know the new config. As the SDK should only call configure once when starting, we do accept
/// this race condition. Adding locks for evaluating the log level for every log invocation isn't
/// acceptable, as this adds a significant overhead for every log call. Therefore, we exclude SentryLog
/// from the ThreadSanitizer as it produces false positives. The tests call configure multiple times,
/// and the thread sanitizer would surface these race conditions. We accept these race conditions for
/// the log messages in the tests over adding locking for all log messages.
@objc
@_spi(Private) public class SentrySDKLog: NSObject {
    
    static private(set) var isDebug = true
    static private(set) var diagnosticLevel = SentryLevel.error

    /**
     * Threshold log level to always log, regardless of the current configuration
     */
    static let alwaysLevel = SentryLevel.fatal
    private static var logOutput: ((String) -> Void) = { print($0) }
    private static var dateProvider: SentryCurrentDateProvider = SentryDefaultCurrentDateProvider()

    static func _configure(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        self.isDebug = isDebug
        self.diagnosticLevel = diagnosticLevel
    }
    
    @objc
    public static func log(message: String, andLevel level: SentryLevel) {
        guard willLog(atLevel: level) else { return }
        
        // We use the time interval because date format is
        // expensive and we only care about the time difference between the
        // log messages. We don't use system uptime because of privacy concerns
        // see: NSPrivacyAccessedAPICategorySystemBootTime.
        let time = self.dateProvider.date().timeIntervalSince1970
        logOutput("[Sentry] [\(level)] [\(time)] \(message)")
    }

    /**
     * @return @c YES if the current logging configuration will log statements at the current level,
     * @c NO if not.
     */
    @objc
    public static func willLog(atLevel level: SentryLevel) -> Bool {
        if level == .none {
            return false
        }
        if level.rawValue >= alwaysLevel.rawValue {
            return true
        }
        return isDebug && level.rawValue >= diagnosticLevel.rawValue
    }
 
    #if SENTRY_TEST || SENTRY_TEST_CI
    
    static func setOutput(_ output: @escaping SentryLogOutput) {
        logOutput = output
    }
    
    static func getOutput() -> SentryLogOutput {
        return logOutput
    }
    
    static func setDateProvider(_ dateProvider: SentryCurrentDateProvider) {
        self.dateProvider = dateProvider
    }
    
    #endif
}

extension SentrySDKLog {
    private static func log(level: SentryLevel, message: String, file: String, line: Int) {
        guard willLog(atLevel: level) else { return }
        let path = file as NSString
        let fileName = (path.lastPathComponent as NSString).deletingPathExtension
        log(message: "[\(fileName):\(line)] \(message)", andLevel: level)
    }
    
    static func debug(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .debug, message: message, file: file, line: line)
    }
    
    static func info(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .info, message: message, file: file, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .warning, message: message, file: file, line: line)
    }
    
    static func error(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .error, message: message, file: file, line: line)
    }
    
    static func fatal(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .fatal, message: message, file: file, line: line)
    }
}
