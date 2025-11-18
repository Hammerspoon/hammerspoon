@objc @_spi(Private)
public class SentryMobileProvisionParser: NSObject {
    private var provisionsAllDevices: Bool = false
    private var embeddedProfilePath: String?
    
    // If the profile provisions all devices, it indicates Enterprise distribution
    @objc 
    public var mobileProvisionProfileProvisionsAllDevices: Bool {
        return provisionsAllDevices
    }
    
    // This convenience initializer exists so we can use it from ObjC.
    // Functions with Optional parameters (used for testing) are not available to ObjC
    @objc
    convenience override public init() {
        self.init(nil)
    }
    
    public init(_ path: String?) {
        super.init()
        embeddedProfilePath = path ?? Bundle.main.path(forResource: "embedded", ofType: "mobileprovision")
        guard let embeddedProfilePath else {
            SentrySDKLog.debug("Couldn't find a embedded mobileprovision profile")
            return
        }
        parseProfileFromPath(embeddedProfilePath)
    }
    
    @objc
    public func hasEmbeddedMobileProvisionProfile() -> Bool {
        embeddedProfilePath != nil
    }
    
    private func parseProfileFromPath(_ path: String) {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            SentrySDKLog.debug("Failed to read embedded mobileprovision profile at path \(path)")
            return
        }
        
        // The file is a CMS (PKCS#7) container with a plist embedded inside as text.
        // Convert to Latin-1 to preserve the bytes -> string even if not UTF-8.
        guard let payload = String(data: fileData, encoding: .isoLatin1),
              let startRange = payload.range(of: "<plist"),
              let endRange = payload.range(of: "</plist>") else {
            SentrySDKLog.debug("Failed to parse embedded mobileprovision profile")
            return
        }
        
        let plistRange = startRange.lowerBound ..< payload.index(endRange.upperBound, offsetBy: 0)
        let plistString = String(payload[plistRange])
        guard let plistData = plistString.data(using: .utf8) else { return }

        var format = PropertyListSerialization.PropertyListFormat.xml
        
        guard let obj = try? PropertyListSerialization.propertyList(from: plistData,
                                                                    options: [],
                                                                    format: &format),
              let dict = obj as? [String: Any] else {
            return
        }
        provisionsAllDevices = dict["ProvisionsAllDevices"] as? Bool ?? false
    }
}
