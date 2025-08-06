@_implementationOnly import _SentryPrivate
import Foundation

extension User: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case email
        case username
        case ipAddress = "ip_address"
        case segment
        case name
        case geo
        case data
    }
    
     @available(*, deprecated, message: """
     This method is only deprecated to silence the deprecation warning of the property \
     segment. Our Xcode project has deprecations as warnings and warnings as errors \
     configured. Therefore, compilation fails without marking this init method as \
     deprecated. It is safe to use this deprecated init method. Instead of turning off \
     deprecation warnings for the whole project, we accept the tradeoff of marking this \
     init method as deprecated because we don't expect many users to use it. Sadly, \
     Swift doesn't offer a better way of silencing a deprecation warning.
     """)
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        self.segment = try container.decodeIfPresent(String.self, forKey: .segment)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.geo = try container.decodeIfPresent(Geo.self, forKey: .geo)
        
        self.data = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .data)
        }
    }
}
