@objcMembers
public class SentryExperimentalOptions: NSObject {
    #if canImport(UIKit)
    /**
     * Settings to configure the session replay.
     */
    public var sessionReplay = SentryReplayOptions(sessionSampleRate: 0, errorSampleRate: 0)
    #endif

    func validateOptions(_ options: [String: Any]?) {
        #if canImport(UIKit)
        if let sessionReplayOptions = options?["sessionReplay"] as? [String: Any] {
            sessionReplay = SentryReplayOptions(dictionary: sessionReplayOptions)
        }
        #endif
    }

}
