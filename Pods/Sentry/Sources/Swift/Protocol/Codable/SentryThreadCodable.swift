@_implementationOnly import _SentryPrivate
import Foundation

extension SentryThread: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case threadId = "id"
        case name
        case stacktrace
        case crashed
        case current
        case isMain = "main"
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        guard let threadId = try container.decode(NSNumberDecodableWrapper.self, forKey: .threadId).value else {
            throw DecodingError.dataCorruptedError(forKey: .threadId, in: container, debugDescription: "Can't decode SentryThread because couldn't decode threadId.")
        }
        
        self.init(threadId: threadId)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.stacktrace = try container.decodeIfPresent(SentryStacktrace.self, forKey: .stacktrace)
        self.crashed = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .crashed)?.value
        self.current = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .current)?.value
        self.isMain = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .isMain)?.value
    }
}
