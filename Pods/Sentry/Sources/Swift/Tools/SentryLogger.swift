@_implementationOnly import _SentryPrivate

import Foundation

/// **EXPERIMENTAL** - A structured logging API for Sentry.
///
/// `SentryLogger` provides a structured logging interface that captures log entries
/// and sends them to Sentry. Supports multiple log levels (trace, debug, info, warn, 
/// error, fatal) and allows attaching arbitrary attributes for enhanced context.
///
/// ## Supported Attribute Types
/// - `String`, `Bool`, `Int`, `Double`
/// - `Float` (converted to `Double`)
/// - Other types (converted to string)
///
/// - Note: Sentry Logs is currently in Beta. See the [Sentry Logs Documentation](https://docs.sentry.io/product/explore/logs/).
/// - Warning: This API is experimental and subject to change without notice.
///
/// ## Usage
/// ```swift
/// let logger = SentrySDK.logger
/// logger.info("User logged in", attributes: ["userId": "12345"])
/// logger.error("Payment failed", attributes: ["errorCode": 500])
/// 
/// // Structured string interpolation with automatic type detection
/// logger.info("User \(userId) processed \(count) items with \(percentage)% success")
/// logger.debug("Processing \(itemCount) items, active: \(isActive)")
/// logger.warn("Retry attempt \(currentAttempt) of \(maxAttempts) failed")
/// ```
@objc
public final class SentryLogger: NSObject {
    private let hub: SentryHub
    private let dateProvider: SentryCurrentDateProvider
    // Nil in the case where the Hub's client is nil or logs are disabled through options.
    private let batcher: SentryLogBatcher?
    
    @_spi(Private) public init(hub: SentryHub, dateProvider: SentryCurrentDateProvider, batcher: SentryLogBatcher?) {
        self.hub = hub
        self.dateProvider = dateProvider
        self.batcher = batcher
        super.init()
    }
    
    // MARK: - Trace Level
    
    /// Logs a trace-level message with structured string interpolation and optional attributes.
    public func trace(_ message: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .trace, logMessage: message, attributes: attributes)
    }
    
    /// Logs a trace-level message.
    @objc(trace:)
    public func trace(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .trace, logMessage: message, attributes: [:])
    }
    
    /// Logs a trace-level message with additional attributes.
    @objc(trace:attributes:)
    public func trace(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .trace, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Debug Level
    
    /// Logs a debug-level message with structured string interpolation and optional attributes.
    public func debug(_ message: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .debug, logMessage: message, attributes: attributes)
    }
    
    /// Logs a debug-level message.
    @objc(debug:)
    public func debug(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .debug, logMessage: message, attributes: [:])
    }
    
    /// Logs a debug-level message with additional attributes.
    @objc(debug:attributes:)
    public func debug(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .debug, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Info Level
    
    /// Logs an info-level message with structured string interpolation and optional attributes.
    public func info(_ message: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .info, logMessage: message, attributes: attributes)
    }
    
    /// Logs an info-level message.
    @objc(info:)
    public func info(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .info, logMessage: message, attributes: [:])
    }
    
    /// Logs an info-level message with additional attributes.
    @objc(info:attributes:)
    public func info(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .info, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Warn Level
    
    /// Logs a warning-level message with structured string interpolation and optional attributes.
    public func warn(_ message: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .warn, logMessage: message, attributes: attributes)
    }
    
    /// Logs a warning-level message.
    @objc(warn:)
    public func warn(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .warn, logMessage: message, attributes: [:])
    }
    
    /// Logs a warning-level message with additional attributes.
    @objc(warn:attributes:)
    public func warn(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .warn, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Error Level
    
    /// Logs an error-level message with structured string interpolation and optional attributes.
    public func error(_ message: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .error, logMessage: message, attributes: attributes)
    }
    
    /// Logs an error-level message.
    @objc(error:)
    public func error(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .error, logMessage: message, attributes: [:])
    }
    
    /// Logs an error-level message with additional attributes.
    @objc(error:attributes:)
    public func error(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .error, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Fatal Level
    
    /// Logs a fatal-level message with structured string interpolation and optional attributes.
    public func fatal(_ message: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .fatal, logMessage: message, attributes: attributes)
    }
    
    /// Logs a fatal-level message.
    @objc(fatal:)
    public func fatal(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .fatal, logMessage: message, attributes: [:])
    }
    
    /// Logs a fatal-level message with additional attributes.
    @objc(fatal:attributes:)
    public func fatal(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .fatal, logMessage: message, attributes: attributes)
    }

    // MARK: - Internal
    
    // Captures batched logs sync and return the duration.
    func captureLogs() -> TimeInterval {
        return batcher?.captureLogs() ?? 0.0
    }
    
    // MARK: - Private
    
    private func captureLog(level: SentryLog.Level, logMessage: SentryLogMessage, attributes: [String: Any]) {
        guard let batcher else {
            return
        }
        
        // Convert provided attributes to SentryLog.Attribute format
        var logAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        
        // Add template string if there are interpolations
        if !logMessage.attributes.isEmpty {
            logAttributes["sentry.message.template"] = .init(string: logMessage.template)
        }
        
        // Add attributes from the SentryLogMessage
        for (index, attribute) in logMessage.attributes.enumerated() {
            logAttributes["sentry.message.parameter.\(index)"] = attribute
        }
        
        addDefaultAttributes(to: &logAttributes)
        addOSAttributes(to: &logAttributes)
        addDeviceAttributes(to: &logAttributes)
        addUserAttributes(to: &logAttributes)

        let propagationContextTraceIdString = hub.scope.propagationContextTraceIdString
        let propagationContextTraceId = SentryId(uuidString: propagationContextTraceIdString)
        
        let log = SentryLog(
            timestamp: dateProvider.date(),
            traceId: propagationContextTraceId,
            level: level,
            body: logMessage.message,
            attributes: logAttributes
        )
        
        var processedLog: SentryLog? = log
        if let beforeSendLog = batcher.options.beforeSendLog {
            processedLog = beforeSendLog(log)
        }
        
        if let processedLog {
            SentrySDKLog.log(
                message: "[SentryLogger] \(processedLog.body)",
                andLevel: processedLog.level.toSentryLevel()
            )
            batcher.add(processedLog)
        }
    }

    private func addDefaultAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let batcher else {
            return
        }
        attributes["sentry.sdk.name"] = .init(string: SentryMeta.sdkName)
        attributes["sentry.sdk.version"] = .init(string: SentryMeta.versionString)
        attributes["sentry.environment"] = .init(string: batcher.options.environment)
        if let releaseName = batcher.options.releaseName {
            attributes["sentry.release"] = .init(string: releaseName)
        }
        if let span = hub.scope.span {
            attributes["sentry.trace.parent_span_id"] = .init(string: span.spanId.sentrySpanIdString)
        }
    }

    private func addOSAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let osContext = hub.scope.getContextForKey(SENTRY_CONTEXT_OS_KEY) else {
            return
        }
        if let osName = osContext["name"] as? String {
            attributes["os.name"] = .init(string: osName)
        }
        if let osVersion = osContext["version"] as? String {
            attributes["os.version"] = .init(string: osVersion)
        }
    }
    
    private func addDeviceAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let deviceContext = hub.scope.getContextForKey(SENTRY_CONTEXT_DEVICE_KEY) else {
            return
        }
        // For Apple devices, brand is always "Apple"
        attributes["device.brand"] = .init(string: "Apple")
        
        if let deviceModel = deviceContext["model"] as? String {
            attributes["device.model"] = .init(string: deviceModel)
        }
        if let deviceFamily = deviceContext["family"] as? String {
            attributes["device.family"] = .init(string: deviceFamily)
        }
    }

    private func addUserAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let user = hub.scope.userObject else {
            return
        }
        if let userId = user.userId {
            attributes["user.id"] = .init(string: userId)
        }
        if let userName = user.name {
            attributes["user.name"] = .init(string: userName)
        }
        if let userEmail = user.email {
            attributes["user.email"] = .init(string: userEmail)
        }
    }
}

#if SWIFT_PACKAGE
/**
 * Use this callback to drop or modify a log before the SDK sends it to Sentry. Return `nil` to
 * drop the log.
 */
public typealias SentryBeforeSendLogCallback = (SentryLog) -> SentryLog?

// Makes the `beforeSendLog` property visible as the Swift type `SentryBeforeSendLogCallback`.
// This works around `SentryLog` being only forward declared in the objc header, resulting in 
// compile time issues with SPM builds.
@objc
public extension Options {
    /**
     * Use this callback to drop or modify a log before the SDK sends it to Sentry. Return `nil` to
     * drop the log.
     */
    @objc
    var beforeSendLog: SentryBeforeSendLogCallback? {
        // Note: This property provides SentryLog type safety for SPM builds where the native Objective-C 
        // property cannot be used due to Swift-to-Objective-C bridging limitations.
        get { return value(forKey: "beforeSendLogDynamic") as? SentryBeforeSendLogCallback }
        set { setValue(newValue, forKey: "beforeSendLogDynamic") }
    }
}
#endif // SWIFT_PACKAGE
