@_implementationOnly import _SentryPrivate
import Foundation

extension SentryRequest: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case bodySize = "body_size"
        case cookies
        case headers
        case fragment
        case method
        case queryString = "query_string"
        case url
    }
    
    required convenience public init(from decoder: any Decoder) throws {
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
