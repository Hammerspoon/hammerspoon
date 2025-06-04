import Foundation

@objc
enum SentryANRType: Int {
    case fatalFullyBlocking
    case fatalNonFullyBlocking
    case fullyBlocking
    case nonFullyBlocking
    case unknown
}

@objc
class SentryAppHangTypeMapper: NSObject {

    private enum ExceptionType: String {
        case fatalFullyBlocking = "Fatal App Hang Fully Blocked"
        case fatalNonFullyBlocking = "Fatal App Hang Non Fully Blocked"
        case fullyBlocking = "App Hang Fully Blocked"
        case nonFullyBlocking = "App Hang Non Fully Blocked"
        case unknown = "App Hanging"
    }

    @objc
    static func getExceptionType(anrType: SentryANRType) -> String {
        switch anrType {
        case .fatalFullyBlocking:
            return ExceptionType.fatalFullyBlocking.rawValue
        case .fatalNonFullyBlocking:
            return ExceptionType.fatalNonFullyBlocking.rawValue
        case .fullyBlocking:
            return ExceptionType.fullyBlocking.rawValue
        case .nonFullyBlocking:
            return ExceptionType.nonFullyBlocking.rawValue
        default:
            return ExceptionType.unknown.rawValue
        }
    }
    
    @objc
    static func getFatalExceptionType(nonFatalErrorType: String) -> String {
        if nonFatalErrorType == ExceptionType.nonFullyBlocking.rawValue {
            return ExceptionType.fatalNonFullyBlocking.rawValue
        }
        
        return ExceptionType.fatalFullyBlocking.rawValue
    }

    @objc
    static func isExceptionTypeAppHang(exceptionType: String) -> Bool {
        return ExceptionType(rawValue: exceptionType) != nil
    }
}
