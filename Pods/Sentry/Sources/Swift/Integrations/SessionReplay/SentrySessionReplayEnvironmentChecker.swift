@objc @_spi(Private) public class SentrySessionReplayEnvironmentChecker: NSObject, SentrySessionReplayEnvironmentCheckerProvider {
    /// Represents the reliability assessment of the environment for Session Replay.
    private enum Reliability {
        /// The environment is confirmed to be reliable (no Liquid Glass issues).
        case reliable
        /// The environment is confirmed to be unreliable (Liquid Glass will cause issues).
        case unreliable
        /// Unable to determine reliability (missing data, errors, etc.).
        /// Treated as unreliable defensively.
        case unclear
    }

    private let infoPlistWrapper: SentryInfoPlistWrapperProvider

    @objc public init(infoPlistWrapper: SentryInfoPlistWrapperProvider) {
        self.infoPlistWrapper = infoPlistWrapper
        super.init()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func isReliable() -> Bool {
        // Defensive programming: Assume unreliable environment by default on iOS 26.0+
        // and only mark as safe if we have explicit proof it's not using Liquid Glass.
        //
        // Liquid Glass introduces changes to text rendering that breaks masking in Session Replay.
        // It's used on iOS 26.0+ UNLESS one of these conditions is met:
        // 1. UIDesignRequiresCompatibility is explicitly set to YES in Info.plist
        // 2. The app was built with Xcode < 26.0 (DTXcode < 2600)

        // Run all checks and return true (reliable) if ANY check confirms reliability
        if checkIOSVersion() == .reliable {
            return true
        }
        if checkCompatibilityMode() == .reliable {
            return true
        }
        if checkXcodeVersion() == .reliable {
            return true
        }

        // No proof of reliability found - treat as unreliable (defensively)
        SentrySDKLog.warning("[Session Replay] Detected environment as unreliable - no proof of reliability found")
        return false
    }

    private func checkIOSVersion() -> Reliability {
        guard #available(iOS 26.0, *) else {
            SentrySDKLog.debug("[Session Replay] Running on iOS version prior to 26.0+ - reliable")
            return .reliable
        }
        SentrySDKLog.debug("[Session Replay] Running on iOS 26.0+")
        return .unclear
    }

    private func checkCompatibilityMode() -> Reliability {
        do {
            var error: NSError?
            let isRequired = infoPlistWrapper.getAppValueBoolean(
                for: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
                errorPtr: &error
            )
            if let error = error as Error? {
                throw error
            }
            if isRequired {
                SentrySDKLog.debug("[Session Replay] UIDesignRequiresCompatibility = YES - reliable")
                return .reliable
            }
            
            SentrySDKLog.debug("[Session Replay] UIDesignRequiresCompatibility = NO - unreliable")
            return .unreliable
        } catch SentryInfoPlistError.mainInfoPlistNotFound {
            SentrySDKLog.warning("[Session Replay] Info.plist not found - unclear")
            return .unclear
        } catch SentryInfoPlistError.keyNotFound {
            // Key not found means the default behavior applies (no compatibility mode)
            SentrySDKLog.debug("[Session Replay] UIDesignRequiresCompatibility not set - unclear")
            return .unclear
        } catch {
            SentrySDKLog.error("[Session Replay] Failed to read Info.plist: \(error) - unclear")
            return .unclear
        }
    }

    private func checkXcodeVersion() -> Reliability {
        do {
            // DTXcode format: Xcode 16.4 = "1640", Xcode 26.0 = "2600"
            let xcodeVersionString = try infoPlistWrapper.getAppValueString(
                for: SentryInfoPlistKey.xcodeVersion.rawValue
            )
            guard let xcodeVersion = Int(xcodeVersionString) else {
                SentrySDKLog.warning("[Session Replay] DTXcode value '\(xcodeVersionString)' is not a valid integer - unclear")
                return .unclear
            }
            if xcodeVersion >= SentryXcodeVersion.xcode26.rawValue {
                SentrySDKLog.debug("[Session Replay] Built with Xcode \(xcodeVersionString) (>= 26.0) - unreliable")
                return .unreliable
            }

            SentrySDKLog.debug("[Session Replay] Built with Xcode \(xcodeVersionString) (< 26.0) - reliable")
            return .reliable
        } catch SentryInfoPlistError.mainInfoPlistNotFound {
            SentrySDKLog.warning("[Session Replay] Info.plist not found - unclear")
            return .unclear
        } catch SentryInfoPlistError.keyNotFound {
            SentrySDKLog.debug("[Session Replay] DTXcode not found in Info.plist - unclear")
            return .unclear
        } catch {
            SentrySDKLog.error("[Session Replay] Failed to read Info.plist: \(error) - unclear")
            return .unclear
        }
    }
}
