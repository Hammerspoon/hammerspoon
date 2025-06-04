import Foundation

@objcMembers
class SentrySwizzleClassNameExclude: NSObject {
    static func shouldExcludeClass(className: String, swizzleClassNameExcludes: Set<String>) -> Bool {
        for exclude in swizzleClassNameExcludes {
            if className.contains(exclude) {
                SentryLog.debug("Excluding class \(className) from swizzling cause it matches the exclude pattern: \(exclude).")
                return true
            }
        }
        return false
    }
}
