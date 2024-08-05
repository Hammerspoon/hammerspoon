import Foundation

@objc
public enum SentryLevel: UInt {
    @objc(kSentryLevelNone)
    case none = 0
    
    // Goes from Debug to Fatal so possible to: (level > Info) { .. }
    @objc(kSentryLevelDebug)
    case debug = 1
    
    @objc(kSentryLevelInfo)
    case info = 2
    
    @objc(kSentryLevelWarning)
    case warning = 3
    
    @objc(kSentryLevelError)
    case error = 4
    
    @objc(kSentryLevelFatal)
    case fatal = 5
}
