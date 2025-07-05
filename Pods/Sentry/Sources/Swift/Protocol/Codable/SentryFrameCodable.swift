@_implementationOnly import _SentryPrivate
import Foundation

// See `develop-docs/README.md` for an explanation of this pattern.
#if SENTRY_SWIFT_PACKAGE
final class FrameDecodable: Frame {
    convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
}
#else
typealias FrameDecodable = Frame
#endif
extension FrameDecodable: Decodable {

    enum CodingKeys: String, CodingKey {
        case symbolAddress = "symbol_addr"
        case fileName = "filename"
        case function
        case module
        case package
        case imageAddress = "image_addr"
        case platform
        case instructionAddress = "instruction_addr"
        // Leaving out instruction on purpose. The event payload does not contain this field
        // and SentryFrame.serialize doesn't add it to the serialized dict.
        // We will remove the property in the next major see:
        // https://github.com/getsentry/sentry-cocoa/issues/4738
        case lineNumber = "lineno"
        case columnNumber = "colno"
        case inApp = "in_app"
        case stackStart = "stack_start"
    }

    #if !SENTRY_SWIFT_PACKAGE
    required convenience public init(from decoder: any Decoder) throws {
        try self.init(decodedFrom: decoder)
    }
    #endif

    private convenience init(decodedFrom decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.symbolAddress = try container.decodeIfPresent(String.self, forKey: .symbolAddress)
        self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        self.function = try container.decodeIfPresent(String.self, forKey: .function)
        self.module = try container.decodeIfPresent(String.self, forKey: .module)
        self.package = try container.decodeIfPresent(String.self, forKey: .package)
        self.imageAddress = try container.decodeIfPresent(String.self, forKey: .imageAddress)
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
        self.instructionAddress = try container.decodeIfPresent(String.self, forKey: .instructionAddress)
        self.lineNumber = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .lineNumber))?.value
        self.columnNumber = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .columnNumber))?.value
        self.inApp = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .inApp))?.value
        self.stackStart = (try container.decodeIfPresent(NSNumberDecodableWrapper.self, forKey: .stackStart))?.value
    }
}
