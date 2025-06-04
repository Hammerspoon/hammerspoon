@_implementationOnly import _SentryPrivate
import Foundation

extension Geo: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case city
        case countryCode = "country_code"
        case region
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
    }
}
