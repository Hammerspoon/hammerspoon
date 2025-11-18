@_implementationOnly import _SentryPrivate
import Foundation

#if SDK_V9
final class SentryMessageDecodable: SentryMessage {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias SentryMessageDecodable = SentryMessage
#endif
extension SentryMessageDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case formatted
        case message
        case params
    }
    
    #if !SDK_V9
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let formatted = try container.decode(String.self, forKey: .formatted)
        self.init(formatted: formatted)
        
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.params = try container.decodeIfPresent([String].self, forKey: .params)
    }
}
