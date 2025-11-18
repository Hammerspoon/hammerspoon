@_implementationOnly import _SentryPrivate
import Foundation

#if SDK_V9
final class SentryNSErrorDecodable: SentryNSError {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias SentryNSErrorDecodable = SentryNSError
#endif
extension SentryNSErrorDecodable: Decodable {

    enum CodingKeys: String, CodingKey {
        case domain
        case code
    }
    
    #if !SDK_V9
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let domain = try container.decode(String.self, forKey: .domain)
        let code = try container.decode(Int.self, forKey: .code)
        self.init(domain: domain, code: code)
    }
}
