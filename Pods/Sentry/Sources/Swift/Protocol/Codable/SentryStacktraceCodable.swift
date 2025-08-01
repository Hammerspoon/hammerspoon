@_implementationOnly import _SentryPrivate
import Foundation

#if SDK_V9
final class SentryStacktraceDecodable: SentryStacktrace {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias SentryStacktraceDecodable = SentryStacktrace
#endif
extension SentryStacktraceDecodable: Decodable {

    enum CodingKeys: String, CodingKey {
        case frames
        case registers
        case snapshot
    }
    
    #if !SDK_V9
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let frames = try container.decodeIfPresent([FrameDecodable].self, forKey: .frames) ?? []
        let registers = try container.decodeIfPresent([String: String].self, forKey: .registers) ?? [:]
        self.init(frames: frames, registers: registers)
        
        let snapshot = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .snapshot)
        self.snapshot = snapshot?.value
    }
}
