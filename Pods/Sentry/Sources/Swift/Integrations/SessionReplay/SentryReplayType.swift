import Foundation

@objc
enum SentryReplayType: Int {
    case session
    case buffer
}

extension SentryReplayType {
    func toString() -> String {
        switch self {
            case .buffer: return "buffer"
            case .session:  return "session"
        }
    }
}
