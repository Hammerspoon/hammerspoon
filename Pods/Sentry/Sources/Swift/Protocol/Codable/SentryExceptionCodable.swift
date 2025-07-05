@_implementationOnly import _SentryPrivate
import Foundation

// See `develop-docs/README.md` for an explanation of this pattern.
#if SENTRY_SWIFT_PACKAGE
final class ExceptionDecodable: Exception {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias ExceptionDecodable = Exception
#endif
extension ExceptionDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case value
        case type
        case mechanism
        case module
        case threadId = "thread_id"
        case stacktrace   
    }

    #if !SENTRY_SWIFT_PACKAGE
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let value = try container.decode(String.self, forKey: .value)
        let type = try container.decode(String.self, forKey: .type)

        self.init(value: value, type: type)

        self.mechanism = try container.decodeIfPresent(MechanismDecodable.self, forKey: .mechanism)
        self.module = try container.decodeIfPresent(String.self, forKey: .module)
        self.threadId = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .threadId)?.value
        self.stacktrace = try container.decodeIfPresent(SentryStacktraceDecodable.self, forKey: .stacktrace)
    }
}
