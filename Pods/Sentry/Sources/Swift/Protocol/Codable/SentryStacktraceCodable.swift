@_implementationOnly import _SentryPrivate
import Foundation

extension SentryStacktrace: Decodable {

    enum CodingKeys: String, CodingKey {
        case frames
        case registers
        case snapshot
    }
    
    required convenience public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let frames = try container.decodeIfPresent([Frame].self, forKey: .frames) ?? []
        let registers = try container.decodeIfPresent([String: String].self, forKey: .registers) ?? [:]
        self.init(frames: frames, registers: registers)
        
        let snapshot = try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .snapshot)
        self.snapshot = snapshot?.value
    }
}
