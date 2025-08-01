@_implementationOnly import _SentryPrivate
import Foundation

// See `develop-docs/README.md` for an explanation of this pattern.
#if SENTRY_SWIFT_PACKAGE
final class BreadcrumbDecodable: Breadcrumb {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias BreadcrumbDecodable = Breadcrumb
#endif
extension BreadcrumbDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case level
        case category
        case timestamp
        case type
        case message
        case data
        case origin
    }
    
    #if !SENTRY_SWIFT_PACKAGE
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()
        
        let rawLevel = try container.decode(String.self, forKey: .level)
        let level = SentryLevelHelper.levelForName(rawLevel)
        SentryLevelBridge.setBreadcrumbLevel(self, level: level.rawValue)
        
        self.category = try container.decode(String.self, forKey: .category)
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.origin = try container.decodeIfPresent(String.self, forKey: .origin)
        
        self.data = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .data)
        }
    }
}
