@_implementationOnly import _SentryPrivate
import Foundation

// See `develop-docs/README.md` for an explanation of this pattern.
#if SENTRY_SWIFT_PACKAGE
final class MechanismMetaDecodable: MechanismMeta {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias MechanismMetaDecodable = MechanismMeta
#endif
extension MechanismMetaDecodable: Decodable {

    enum CodingKeys: String, CodingKey {
        case signal
        case machException = "mach_exception"
        case error = "ns_error"
    }
    
    #if !SENTRY_SWIFT_PACKAGE
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.signal = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .signal)
        }
        self.machException = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .machException)
        }
        self.error = try container.decodeIfPresent(SentryNSErrorDecodable.self, forKey: .error)
    }
}
