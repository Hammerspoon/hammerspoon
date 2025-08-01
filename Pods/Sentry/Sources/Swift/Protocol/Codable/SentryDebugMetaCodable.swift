@_implementationOnly import _SentryPrivate
import Foundation

// See `develop-docs/README.md` for an explanation of this pattern.
#if SENTRY_SWIFT_PACKAGE
final class DebugMetaDecodable: DebugMeta {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias DebugMetaDecodable = DebugMeta
#endif
extension DebugMetaDecodable: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case debugID = "debug_id"
        case type
        case name
        case imageSize = "image_size"
        case imageAddress = "image_addr"
        case imageVmAddress = "image_vmaddr"
        case codeFile = "code_file"
    }
    
    #if !SENTRY_SWIFT_PACKAGE
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init()
        
        self.uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
        self.debugID = try container.decodeIfPresent(String.self, forKey: .debugID)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.imageSize = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .imageSize))?.value
        self.imageAddress = try container.decodeIfPresent(String.self, forKey: .imageAddress)
        self.imageVmAddress = try container.decodeIfPresent(String.self, forKey: .imageVmAddress)
        self.codeFile = try container.decodeIfPresent(String.self, forKey: .codeFile)
    
    }
}
