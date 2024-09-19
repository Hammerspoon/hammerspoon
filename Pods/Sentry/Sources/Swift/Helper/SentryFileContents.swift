import Foundation

@objcMembers
class SentryFileContents: NSObject {
    
    let path: String
    let contents: Data
    
    init(path: String, contents: Data) {
        self.path = path
        self.contents = contents
    }
}
