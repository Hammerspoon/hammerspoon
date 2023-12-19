import Foundation

@objc
public class SwiftDescriptor: NSObject {
    
    @objc
    public static func getObjectClassName(_ object: AnyObject) -> String {
        return String(describing: type(of: object))
    }
    
    @objc
    public static func getSwiftErrorDescription(_ error: Error) -> String? {
        return String(describing: error)
    }
    
}
