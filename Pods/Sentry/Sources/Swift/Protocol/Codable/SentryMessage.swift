@_implementationOnly import _SentryPrivate
import Foundation

extension SentryMessage: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case formatted
        case message
        case params
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let formatted = try container.decode(String.self, forKey: .formatted)
        self.init(formatted: formatted)
        
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.params = try container.decodeIfPresent([String].self, forKey: .params)
    }
}
