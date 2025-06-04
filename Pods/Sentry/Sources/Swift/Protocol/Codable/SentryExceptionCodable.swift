@_implementationOnly import _SentryPrivate
import Foundation

extension Exception: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case value
        case type
        case mechanism
        case module
        case threadId = "thread_id"
        case stacktrace   
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let value = try container.decode(String.self, forKey: .value)
        let type = try container.decode(String.self, forKey: .type)

        self.init(value: value, type: type)

        self.mechanism = try container.decodeIfPresent(Mechanism.self, forKey: .mechanism)
        self.module = try container.decodeIfPresent(String.self, forKey: .module)
        self.threadId = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .threadId)?.value
        self.stacktrace = try container.decodeIfPresent(SentryStacktrace.self, forKey: .stacktrace)
    }
}
