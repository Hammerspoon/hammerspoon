@_implementationOnly import _SentryPrivate
import Foundation

extension MechanismMeta: Decodable {

    enum CodingKeys: String, CodingKey {
        case signal
        case machException = "mach_exception"
        case error = "ns_error"
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.signal = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .signal)
        }
        self.machException = decodeArbitraryData {
            try container.decodeIfPresent([String: ArbitraryData].self, forKey: .machException)
        }
        self.error = try container.decodeIfPresent(SentryNSError.self, forKey: .error)
    }
}
