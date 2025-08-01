extension SentryLog {
    enum Level: String, Codable {
        case trace
        case debug
        case info
        case warn
        case error
        case fatal
        
        // Docs: https://develop.sentry.dev/sdk/telemetry/logs/#log-severity-number
        func toSeverityNumber() -> Int {
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
