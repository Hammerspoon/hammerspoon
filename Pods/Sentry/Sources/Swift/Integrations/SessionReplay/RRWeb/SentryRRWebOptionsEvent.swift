@_implementationOnly import _SentryPrivate
import Foundation

@objc class SentryRRWebOptionsEvent: SentryRRWebCustomEvent {
    
    init(timestamp: Date, customOptions: [String: Any]) {
        super.init(timestamp: timestamp, tag: "options", payload: customOptions)
    }
    
    init(timestamp: Date, options: SentryReplayOptions) {
        var payload: [String: Any] = [
            "sessionSampleRate": options.sessionSampleRate,
            "errorSampleRate": options.onErrorSampleRate,
            "maskAllText": options.maskAllText,
            "maskAllImages": options.maskAllImages,
            "quality": String(describing: options.quality),
            "nativeSdkName": SentryMeta.sdkName,
            "nativeSdkVersion": SentryMeta.versionString
        ]
        
        if !options.maskedViewClasses.isEmpty {
            payload["maskedViewClasses"] = options.maskedViewClasses.map(String.init(describing:)).joined(separator: ", ")
        }
        
        if !options.unmaskedViewClasses.isEmpty {
            payload["unmaskedViewClasses"] = options.unmaskedViewClasses.map(String.init(describing:)).joined(separator: ", ")
        }
        
        super.init(timestamp: timestamp, tag: "options", payload: payload)
    }
}
