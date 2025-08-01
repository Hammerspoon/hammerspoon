import Foundation

@objcMembers
@_spi(Private) public class SentrySwizzleClassNameExclude: NSObject {
    public static func shouldExcludeClass(className: String, swizzleClassNameExcludes: Set<String>) -> Bool {
        for exclude in swizzleClassNameExcludes {
            if className.contains(exclude) {
                SentrySDKLog.debug("Excluding class \(className) from swizzling cause it matches the exclude pattern: \(exclude).")
                return true
            }
        }
        return false
    }
}
