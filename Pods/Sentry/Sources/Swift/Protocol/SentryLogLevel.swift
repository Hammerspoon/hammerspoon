extension SentryLog {
    /// Represents the severity level of a structured log entry.
    ///
    /// Log levels are ordered by severity from least (`trace`) to most severe (`fatal`).
    /// Each level corresponds to a numeric severity value following the OpenTelemetry specification.
    @objc(SentryStructuredLogLevel)
    public enum Level: Int {
        case trace
        case debug
        case info
        case warn
        case error
        case fatal
        
        /// Creates a log level from its string representation.
        ///
        /// - Parameter value: The string representation of the log level
        /// - Throws: An error if the string doesn't match any known log level
        public init(value: String) throws {
            switch value {
            case "trace":
                self = .trace
            case "debug":
                self = .debug
            case "info":
                self = .info
            case "warn":
                self = .warn
            case "error":
                self = .error
            case "fatal":
                self = .fatal
            default:
                throw NSError(domain: "SentryLogLevel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown log level: \(value)"])
            }
        }
        
        /// The string representation of the log level.
        public var value: String {
            switch self {
            case .trace:
                return "trace"
            case .debug:
                return "debug"
            case .info:
                return "info"
            case .warn:
                return "warn"
            case .error:
                return "error"
            case .fatal:
                return "fatal"
            }
        }
        
        /// Converts the log level to its numeric severity representation (1-21) following the OpenTelemetry specification.
        /// Docs: https://develop.sentry.dev/sdk/telemetry/logs/#log-severity-number
        public func toSeverityNumber() -> Int {
            switch self {
            case .trace:
                return 1
            case .debug:
                return 5
            case .info:
                return 9
            case .warn:
                return 13
            case .error:
                return 17
            case .fatal:
                return 21
            }
        }
    }
}

// MARK: - Internal Codable Support
@_spi(Private) extension SentryLog.Level: Codable {
    @_spi(Private) public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        self = try .init(value: stringValue)
    }
    
    @_spi(Private) public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

@_spi(Private) extension SentryLog.Level {
    /// Converts the structured log level to the legacy SentryLevel for compatibility with SentrySDKLog
    @_spi(Private) public func toSentryLevel() -> SentryLevel {
        switch self {
        case .trace, .debug:
            return .debug
        case .info:
            return .info
        case .warn:
            return .warning
        case .error:
            return .error
        case .fatal:
            return .fatal
        }
    }
}
