@_implementationOnly import _SentryPrivate
import Foundation

extension Mechanism: Decodable {

    enum CodingKeys: String, CodingKey {
        case type
        case handled
        case synthetic
        case desc = "description"
        case data
        case helpLink = "help_link"
        case meta
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(String.self, forKey: .type)
        self.init(type: type)
        
        self.desc = try container.decodeIfPresent(String.self, forKey: .desc)
        self.data = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .data)
        }
        self.handled = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .handled)?.value
        self.synthetic = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .synthetic)?.value
        self.helpLink = try container.decodeIfPresent(String.self, forKey: .helpLink)
        self.meta = try container.decodeIfPresent(MechanismMeta.self, forKey: .meta)
    }
}
