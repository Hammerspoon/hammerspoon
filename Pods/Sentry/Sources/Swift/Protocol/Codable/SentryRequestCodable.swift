@_implementationOnly import _SentryPrivate
import Foundation

// See `develop-docs/README.md` for an explanation of this pattern.
#if SENTRY_SWIFT_PACKAGE
final class SentryRequestDecodable: SentryRequest {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias SentryRequestDecodable = SentryRequest
#endif
extension SentryRequestDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case bodySize = "body_size"
        case cookies
        case headers
        case fragment
        case method
        case queryString = "query_string"
        case url
    }
    
    #if !SENTRY_SWIFT_PACKAGE
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()
        
        self.bodySize = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .bodySize)?.value
        self.cookies = try container.decodeIfPresent(String.self, forKey: .cookies)
        self.headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        self.fragment = try container.decodeIfPresent(String.self, forKey: .fragment)
        self.method = try container.decodeIfPresent(String.self, forKey: .method)
        self.queryString = try container.decodeIfPresent(String.self, forKey: .queryString)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
    }
}
