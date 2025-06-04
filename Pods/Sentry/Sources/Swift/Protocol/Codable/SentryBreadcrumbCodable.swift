@_implementationOnly import _SentryPrivate
import Foundation

extension Breadcrumb: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case level
        case category
        case timestamp
        case type
        case message
        case data
        case origin
    }
    
    required convenience public init(from decoder: any Decoder) throws {
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
