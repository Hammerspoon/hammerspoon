@_implementationOnly import _SentryPrivate
import Foundation

/// This is required to identify the package manager used when installing sentry.
private enum SentryPackageManagerOption: UInt {
    case swiftPackageManager = 0
    case cocoaPods = 1
    case carthage = 2
    case unknown = 3
}

#if SWIFT_PACKAGE
private var SENTRY_PACKAGE_INFO: SentryPackageManagerOption = .swiftPackageManager
#elseif COCOAPODS
private var SENTRY_PACKAGE_INFO: SentryPackageManagerOption = .cocoaPods
#elseif CARTHAGE_YES
// CARTHAGE is a xcodebuild build setting with value `YES`, we need to convert it into a compiler
// definition to be able to use it.
private var SENTRY_PACKAGE_INFO: SentryPackageManagerOption = .carthage
#else
private var SENTRY_PACKAGE_INFO: SentryPackageManagerOption = .unknown
#endif

@objc
@_spi(Private) public final class SentrySdkPackage: NSObject {

    private static func getSentrySDKPackageName(_ packageManager: SentryPackageManagerOption) -> String? {
        switch packageManager {
        case .swiftPackageManager:
            return "spm:getsentry/\(SentryMeta.sdkName)"
        case .cocoaPods:
            return "cocoapods:getsentry/\(SentryMeta.sdkName)"
        case .carthage:
            return "carthage:getsentry/\(SentryMeta.sdkName)"
        case .unknown:
            return nil
        }
    }

    private static func getSentrySDKPackage(_ packageManager: SentryPackageManagerOption) -> [String: String]? {
        if packageManager == .unknown {
            return nil
        }

        guard let name = getSentrySDKPackageName(packageManager) else {
            return nil
         }

        return ["name": name, "version": SentryMeta.versionString]
    }

    @objc
    public static func global() -> [String: String]? {
        return getSentrySDKPackage(SENTRY_PACKAGE_INFO)
    }

    #if SENTRY_TEST || SENTRY_TEST_CI
    @objc
    public static func setPackageManager(_ manager: UInt) {
        SENTRY_PACKAGE_INFO = SentryPackageManagerOption(rawValue: manager) ?? .unknown
    }

    @objc
    public static func resetPackageManager() {
        SENTRY_PACKAGE_INFO = .unknown
    }
    #endif
}
