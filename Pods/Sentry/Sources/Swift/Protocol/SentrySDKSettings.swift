/**
 * Describes the settings for the Sentry SDK
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@_spi(Private) @objc public final class SentrySDKSettings: NSObject {
    
    @objc public override init() {
        autoInferIP = false
    }
    
    @objc public init(options: Options?) {
        autoInferIP = options?.sendDefaultPii ?? false
    }
    
    @objc public init(dict: NSDictionary) {
        if let inferIp = dict["infer_ip"] as? String {
            autoInferIP = inferIp == "auto"
        } else {
            autoInferIP = false
        }
    }
    
    @objc public var autoInferIP: Bool
    
    @objc public func serialize() -> NSDictionary {
        [
            "infer_ip": autoInferIP ? "auto" : "never"
        ]
    }
}
