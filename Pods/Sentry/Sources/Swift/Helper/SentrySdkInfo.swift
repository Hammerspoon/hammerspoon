@_implementationOnly import _SentryPrivate
import Foundation

/**
 * Describes the Sentry SDK and its configuration used to capture and transmit an event.
 * @note Both name and version are required.
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@_spi(Private) @objc public final class SentrySdkInfo: NSObject, SentrySerializable {
    
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    @objc public static func global() -> Self {
        Self(withOptions: SentrySDKInternal.currentHub().getClient()?.options)
    }
    
    /**
     * The name of the SDK. Examples: sentry.cocoa, sentry.cocoa.vapor, ...
     */
    @objc public let name: String
    
    /**
     * The version of the SDK. It should have the Semantic Versioning format MAJOR.MINOR.PATCH, without
     * any prefix (no v or anything else in front of the major version number). Examples:
     * 0.1.0, 1.0.0, 2.0.0-beta0
     */
    @objc public let version: String
    
    /**
     * A list of names identifying enabled integrations. The list should
     * have all enabled integrations, including default integrations. Default
     * integrations are included because different SDK releases may contain different
     * default integrations.
     */
    @objc public let integrations: [String]
    
    /**
     * A list of feature names identifying enabled SDK features. This list
     * should contain all enabled SDK features. On some SDKs, enabling a feature in the
     * options also adds an integration. We encourage tracking such features with either
     * integrations or features but not both to reduce the payload size.
     */
    @objc public let features: [String]
    
    /**
     * A list of packages that were installed as part of this SDK or the
     * activated integrations. Each package consists of a name in the format
     * source:identifier and version.
     */
    @objc public let packages: [[String: String]]
    
    /**
     * A set of settings as part of this SDK.
     */
    @objc public let settings: SentrySDKSettings
    
    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    @objc public convenience init(withOptions options: Options?) {
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        var integrations = SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames()
        #if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
            if options?.enablePreWarmedAppStartTracing ?? false {
                integrations.append("PreWarmedAppStartTracing")
            }
        #endif
        var packages = SentryExtraPackages.getPackages()
        let sdkPackage = SentrySdkPackage.global()
        if let sdkPackage {
            packages.insert(sdkPackage)
        }
        self.init(
            name: SentryMeta.sdkName,
            version: SentryMeta.versionString,
            integrations: integrations,
            features: features,
            packages: Array(packages),
            settings: SentrySDKSettings(options: options))
    }
    
    @objc public init(name: String?, version: String?, integrations: [String]?, features: [String]?, packages: [[String: String]]?, settings: SentrySDKSettings) {
        self.name = name ?? ""
        self.version = version ?? ""
        self.integrations = integrations ?? []
        self.features = features ?? []
        self.packages = packages ?? []
        self.settings = settings
    }
    
    // swiftlint:disable cyclomatic_complexity
    @objc
    public convenience init(dict: [AnyHashable: Any]) {
        var name = ""
        var version = ""
        var integrations = Set<String>()
        var features = Set<String>()
        var packages = Set<[String: String]>()
        var settings = SentrySDKSettings(dict: [:])

        if let nameValue = dict["name"] as? String {
            name = nameValue
        }

        if let versionValue = dict["version"] as? String {
            version = versionValue
        }

        if let integrationArray = dict["integrations"] as? [Any] {
            for item in integrationArray {
                if let integration = item as? String {
                    integrations.insert(integration)
                }
            }
        }

        if let featureArray = dict["features"] as? [Any] {
            for item in featureArray {
                if let feature = item as? String {
                    features.insert(feature)
                }
            }
        }

        if let packageArray = dict["packages"] as? [Any] {
            for item in packageArray {
                if let package = item as? [String: Any],
                   let name = package["name"] as? String,
                   let version = package["version"] as? String {
                    packages.insert(["name": name, "version": version])
                }
            }
        }

        if let settingsDict = dict["settings"] as? NSDictionary {
            settings = SentrySDKSettings(dict: settingsDict)
        }

        self.init(
            name: name,
            version: version,
            integrations: Array(integrations),
            features: Array(features),
            packages: Array(packages),
            settings: settings
        )
    }
    // swiftlint:enable cyclomatic_complexity
    
    @objc public func serialize() -> [String: Any] {
        [
            "name": self.name,
            "version": self.version,
            "integrations": self.integrations,
            "features": self.features,
            "packages": self.packages,
            "settings": self.settings.serialize()
        ]
    }
}
