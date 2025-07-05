import Foundation

@objc
public enum SentryLevel: UInt {
    static let levelNames = ["none", "debug", "info", "warning", "error", "fatal"]
    
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

extension SentryLevel: CustomStringConvertible { 
    public var description: String {
        return SentryLevel.levelNames[Int(self.rawValue)]
    }
    
    static func fromName(_ name: String) -> SentryLevel {
        guard let index = SentryLevel.levelNames.firstIndex(of: name) else { return .error }
        return SentryLevel(rawValue: UInt(index)) ?? .error
    }
}

@objcMembers
@_spi(Private) public class SentryLevelHelper: NSObject {
    public static func nameForLevel(_  level: SentryLevel) -> String {
        return level.description
    }
    
    public static func levelForName(_ name: String) -> SentryLevel {
        .fromName(name)
    }
}
