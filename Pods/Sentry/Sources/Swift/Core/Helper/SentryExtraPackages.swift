import Foundation

@objc @_spi(Private) public final class SentryExtraPackages: NSObject {
    private static var extraPackages = Set<[String: String]>()
    private static let lock = NSRecursiveLock()

    @objc
    public static func addPackageName(_ name: String?, version: String?) {
        guard let name, let version else {
            return
        }

        let newPackage = ["name": name, "version": version]

        _ = lock.synchronized {
            extraPackages.insert(newPackage)
        }
    }

    @objc
    public static func getPackages() -> NSMutableSet {
        lock.synchronized {
            NSMutableSet(set: extraPackages as NSSet)
        }
    }

    #if SENTRY_TEST || SENTRY_TEST_CI
    static func clear() {
        lock.synchronized {
            extraPackages.removeAll()
        }
    }
    #endif
}
