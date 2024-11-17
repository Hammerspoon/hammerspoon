import Foundation

@objc
class SwiftDescriptor: NSObject {
    
    @objc
    static func getObjectClassName(_ object: AnyObject) -> String { 
        return String(describing: type(of: object))
    }
    
    @objc
    static func getSwiftErrorDescription(_ error: Error) -> String? {
        return String(describing: error)
    }
}
