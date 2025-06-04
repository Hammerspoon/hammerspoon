@_implementationOnly import _SentryPrivate
import Foundation

extension SentryNSError: Decodable {

    enum CodingKeys: String, CodingKey {
        case domain
        case code
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let domain = try container.decode(String.self, forKey: .domain)
        let code = try container.decode(Int.self, forKey: .code)
        self.init(domain: domain, code: code)
    }
}
