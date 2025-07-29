import Foundation

@objcMembers
@_spi(Private) public class SentryFileContents: NSObject {
    
    public let path: String
    public let contents: Data
    
    public init(path: String, contents: Data) {
        self.path = path
        self.contents = contents
    }
}
