// swiftlint:disable file_length
import Foundation

@objcMembers
public class SentryReplayOptions: NSObject, SentryRedactOptions {
    /**
     * Default values for the session replay options.
     *
     * - Note: These values are used to ensure the different initializers use the same default values.
     */
    public class DefaultValues {
        public static let sessionSampleRate: Float = 0
        public static let onErrorSampleRate: Float = 0
        public static let maskAllText: Bool = true
        public static let maskAllImages: Bool = true
        public static let enableViewRendererV2: Bool = true
        public static let enableFastViewRendering: Bool = false
        public static let quality: SentryReplayQuality = .medium

        // The following properties are public because they are used by SentrySwiftUI.

        public static let maskedViewClasses: [AnyClass] = []
        public static let unmaskedViewClasses: [AnyClass] = []

        // The following properties are defaults which are not configurable by the user.

        fileprivate static let sdkInfo: [String: Any]? = nil
        fileprivate static let frameRate: UInt = 1
        fileprivate static let errorReplayDuration: TimeInterval = 30
        fileprivate static let sessionSegmentDuration: TimeInterval = 5
        fileprivate static let maximumDuration: TimeInterval = 60 * 60
    }

    /**
     * Enum to define the quality of the session replay.
     */
    @objc
    public enum SentryReplayQuality: Int, CustomStringConvertible {
        /**
         * Video Scale: 80%
         * Bit Rate: 20.000
         */
        case low

        /**
         * Video Scale: 100%
         * Bit Rate: 40.000
         */
        case medium

        /**
         * Video Scale: 100%
         * Bit Rate: 60.000
         */
        case high

        public var description: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            }
        }

        /**
         * Used by Hybrid SDKs.
         */
        static func fromName(_ name: String) -> SentryReplayOptions.SentryReplayQuality {
            switch name {
            case "low": return .low
            case "medium": return .medium
            case "high": return .high
            default: return DefaultValues.quality
            }
        }

        /**
         * Converts a nullable Int to a SentryReplayQuality.
         *
         * This method extends the ``SentryReplayQuality.init(rawValue:)`` by supporting nil values.
         *
         * - Parameter rawValue: The raw value to convert.
         * - Returns: Corresponding ``SentryReplayQuality`` or `nil` if not a valid raw value or no value is provided.
         */
        fileprivate static func from(rawValue: Int?) -> SentryReplayOptions.SentryReplayQuality? {
            guard let rawValue = rawValue else {
                return nil
            }
            return SentryReplayOptions.SentryReplayQuality(rawValue: rawValue)
        }

        fileprivate var bitrate: Int {
            self.rawValue * 20_000 + 20_000
        }

        fileprivate var sizeScale: Float {
            self == .low ? 0.8 : 1.0
        }
    }

    /**
     * Indicates the percentage in which the replay for the session will be created.
     *
     * - Specifying @c 0 means never, @c 1.0 means always.
     * - Note: The value needs to be `>= 0.0` and `<= 1.0`. When setting a value out of range the SDK sets it
     * to the default.
     * - Note: See ``SentryReplayOptions.DefaultValues.sessionSegmentDuration`` for the default duration of the replay.
     */
    public var sessionSampleRate: Float

    /**
     * Indicates the percentage in which a 30 seconds replay will be send with error events.
     * - Specifying 0 means never, 1.0 means always.
     *
     * - Note: The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * - Note: See ``SentryReplayOptions.DefaultValues.errorReplayDuration`` for the default duration of the replay.
     */
    public var onErrorSampleRate: Float

    /**
     * Indicates whether session replay should redact all text in the app
     * by drawing a black rectangle over it.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskAllText`` for the default value.
     */
    public var maskAllText: Bool

    /**
     * Indicates whether session replay should redact all non-bundled image
     * in the app by drawing a black rectangle over it.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskAllImages`` for the default value.
     */
    public var maskAllImages: Bool

    /**
     * Indicates the quality of the replay.
     * The higher the quality, the higher the CPU and bandwidth usage.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.quality`` for the default value.
     */
    public var quality: SentryReplayQuality

    /**
     * A list of custom UIView subclasses that need
     * to be masked during session replay.
     * By default Sentry already mask text and image elements from UIKit
     * Every child of a view that is redacted will also be redacted.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskedViewClasses`` for the default value.
     */
    public var maskedViewClasses: [AnyClass]

    /**
     * A list of custom UIView subclasses to be ignored
     * during masking step of the session replay.
     * The views of given classes will not be redacted but their children may be.
     * This property has precedence over `redactViewTypes`.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.unmaskedViewClasses`` for the default value.
     */
    public var unmaskedViewClasses: [AnyClass]

    /**
     * Alias for ``enableViewRendererV2``.
     *
     * This flag is deprecated and will be removed in a future version.
     * Please use ``enableViewRendererV2`` instead.
     */
    @available(*, deprecated, renamed: "enableViewRendererV2")
    public var enableExperimentalViewRenderer: Bool {
        get {
            enableViewRendererV2
        }
        set {
            enableViewRendererV2 = newValue
        }
    }

    /**
     * Enables the up to 5x faster new view renderer used by the Session Replay integration.
     *
     * Enabling this flag will reduce the amount of time it takes to render each frame of the session replay on the main thread, therefore reducing
     * interruptions and visual lag. [Our benchmarks](https://github.com/getsentry/sentry-cocoa/pull/4940) have shown a significant improvement of
     * **up to 4-5x faster rendering** (reducing `~160ms` to `~36ms` per frame) on older devices.
     *
     * - Experiment: In case you are noticing issues with the new view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa).
     *               Eventually, we will remove this feature flag and use the new view renderer by default.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.enableViewRendererV2`` for the default value.
     */
    public var enableViewRendererV2: Bool

    /**
     * Enables up to 5x faster but incommpelte view rendering used by the Session Replay integration.
     *
     * Enabling this flag will reduce the amount of time it takes to render each frame of the session replay on the main thread, therefore reducing
     * interruptions and visual lag. [Our benchmarks](https://github.com/getsentry/sentry-cocoa/pull/4940) have shown a significant improvement of
     * up to **5x faster render times** (reducing `~160ms` to `~30ms` per frame).
     *
     * This flag controls the way the view hierarchy is drawn into a graphics context for the session replay. By default, the view hierarchy is drawn using
     * the `UIView.drawHierarchy(in:afterScreenUpdates:)` method, which is the most complete way to render the view hierarchy. However,
     * this method can be slow, especially when rendering complex views, therefore enabling this flag will switch to render the underlying `CALayer` instead.
     *
     * - Note: This flag can only be used together with `enableViewRendererV2` with up to 20% faster render times.
     * - Warning: Rendering the view hiearchy using the `CALayer.render(in:)` method can lead to rendering issues, especially when using custom views.
     *            For complete rendering, it is recommended to set this option to `false`. In case you prefer performance over completeness, you can
     *            set this option to `true`.
     * - Experiment: This is an experimental feature and is therefore disabled by default. In case you are noticing issues with the experimental
     *               view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa). Eventually, we will
     *               mark this feature as stable and remove the experimental flag, but will keep it disabled by default.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.enableFastViewRendering`` for the default value.
     */
    public var enableFastViewRendering: Bool

    /**
     * Defines the quality of the session replay.
     *
     * Higher bit rates better quality, but also bigger files to transfer.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.quality`` for the default value.
     */
    @_spi(Private) public var replayBitRate: Int {
        quality.bitrate
    }

    /**
     * The scale related to the window size at which the replay will be created
     *
     * - Note: The scale is used to reduce the size of the replay.
     */
    @_spi(Private) public var sizeScale: Float {
        quality.sizeScale
    }

    /**
     * Number of frames per second of the replay.
     * The more the havier the process is.
     * The minimum is 1, if set to zero this will change to 1.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.frameRate`` for the default value.
     */
    @_spi(Private) public var frameRate: UInt {
        didSet {
            if frameRate < 1 {
                frameRate = 1
            }
        }
    }

    /**
     * The maximum duration of replays for error events.
     */
    @_spi(Private) public var errorReplayDuration: TimeInterval

    /**
     * The maximum duration of the segment of a session replay.
     */
    @_spi(Private) public var sessionSegmentDuration: TimeInterval

    /**
     * The maximum duration of a replay session.
     *
     * - Note: See  ``SentryReplayOptions.DefaultValues.maximumDuration`` for the default value.
     */
    @_spi(Private) public var maximumDuration: TimeInterval

    /**
     * Used by hybrid SDKs to be able to configure SDK info for Session Replay
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.sdkInfo`` for the default value.
     */
    var sdkInfo: [String: Any]?

    /**
     * Initialize session replay options disabled
     *
     * - Note: This initializer is added for Objective-C compatibility, as constructors with default values
     *         are not supported in Objective-C.
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public convenience override init() {
        // Setting all properties to nil will fallback to the default values in the init method.
        self.init(
            sessionSampleRate: nil,
            onErrorSampleRate: nil,
            maskAllText: nil,
            maskAllImages: nil,
            enableViewRendererV2: nil,
            enableFastViewRendering: nil,
            maskedViewClasses: nil,
            unmaskedViewClasses: nil,
            quality: nil,
            sdkInfo: nil,
            frameRate: nil,
            errorReplayDuration: nil,
            sessionSegmentDuration: nil,
            maximumDuration: nil
        )
    }

    /**
     * Initializes a new instance of ``SentryReplayOptions`` using a dictionary.
     *
     * - Parameter dictionary: A dictionary containing the configuration options for the session replay.
     *
     * - Warning: This initializer is primarily used by Hybrid SDKs and is not intended for public use.
     */
    @_spi(Private) public convenience init(dictionary: [String: Any]) {
        // This initalizer is calling the one with optional parameters, so that defaults can be applied
        // for absent values.
        self.init(
            sessionSampleRate: (dictionary["sessionSampleRate"] as? NSNumber)?.floatValue,
            onErrorSampleRate: (dictionary["errorSampleRate"] as? NSNumber)?.floatValue,
            maskAllText: (dictionary["maskAllText"] as? NSNumber)?.boolValue,
            maskAllImages: (dictionary["maskAllImages"] as? NSNumber)?.boolValue,
            enableViewRendererV2: (dictionary["enableViewRendererV2"] as? NSNumber)?.boolValue
            ?? (dictionary["enableExperimentalViewRenderer"] as? NSNumber)?.boolValue,
            enableFastViewRendering: (dictionary["enableFastViewRendering"] as? NSNumber)?.boolValue,
            maskedViewClasses: (dictionary["maskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            }),
            unmaskedViewClasses: (dictionary["unmaskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            }),
            quality: SentryReplayQuality.from(rawValue: dictionary["quality"] as? Int),
            sdkInfo: dictionary["sdkInfo"] as? [String: Any],
            frameRate: (dictionary["frameRate"] as? NSNumber)?.uintValue,
            errorReplayDuration: (dictionary["errorReplayDuration"] as? NSNumber)?.doubleValue,
            sessionSegmentDuration: (dictionary["sessionSegmentDuration"] as? NSNumber)?.doubleValue,
            maximumDuration: (dictionary["maximumDuration"] as? NSNumber)?.doubleValue
        )
    }

    /**
     * Initializes a new instance of ``SentryReplayOptions`` with the specified parameters.
     *
     * - Parameters:
     *   - sessionSampleRate: Sample rate used to determine the percentage of replays of sessions that will be uploaded.
     *   - onErrorSampleRate: Sample rate used to determine the percentage of replays of error events that will be uploaded.
     *   - maskAllText: Flag to redact all text in the app by drawing a rectangle over it.
     *   - maskAllImages: Flag to redact all images in the app by drawing a rectangle over it.
     *   - enableViewRendererV2: Enables the up to 5x faster view renderer.
     *   - enableFastViewRendering: Enables faster but incomplete view rendering. See ``SentryReplayOptions.enableFastViewRendering`` for more information.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public convenience init(
        sessionSampleRate: Float = DefaultValues.sessionSampleRate,
        onErrorSampleRate: Float = DefaultValues.onErrorSampleRate,
        maskAllText: Bool = DefaultValues.maskAllText,
        maskAllImages: Bool = DefaultValues.maskAllImages,
        enableViewRendererV2: Bool = DefaultValues.enableViewRendererV2,
        enableFastViewRendering: Bool = DefaultValues.enableFastViewRendering
    ) {
        // - This initializer is publicly available for Swift, but not for Objective-C, because automatically bridged Swift initializers
        //   with default values result in a single initializer requiring all parameters.
        // - Each parameter has a default value, so the parameter can be omitted, which is not possible for Objective-C.
        // - Parameter values are not optional, because SDK users should not be able to set them to nil.
        // - The publicly available property `quality` is omitted in this initializer, because adding it would break backwards compatibility
        //   with the automatically bridged Objective-C initializer.
        self.init(
            sessionSampleRate: sessionSampleRate,
            onErrorSampleRate: onErrorSampleRate,
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            enableViewRendererV2: enableViewRendererV2,
            enableFastViewRendering: enableFastViewRendering,
            maskedViewClasses: nil,
            unmaskedViewClasses: nil,
            quality: nil,
            sdkInfo: nil,
            frameRate: nil,
            errorReplayDuration: nil,
            sessionSegmentDuration: nil,
            maximumDuration: nil
        )
    }

    // swiftlint:disable:next function_parameter_count cyclomatic_complexity
    private init(
        sessionSampleRate: Float?,
        onErrorSampleRate: Float?,
        maskAllText: Bool?,
        maskAllImages: Bool?,
        enableViewRendererV2: Bool?,
        enableFastViewRendering: Bool?,
        maskedViewClasses: [AnyClass]?,
        unmaskedViewClasses: [AnyClass]?,
        quality: SentryReplayQuality?,
        sdkInfo: [String: Any]?,
        frameRate: UInt?,
        errorReplayDuration: TimeInterval?,
        sessionSegmentDuration: TimeInterval?,
        maximumDuration: TimeInterval?
    ) {
        self.sessionSampleRate = sessionSampleRate ?? DefaultValues.sessionSampleRate
        self.onErrorSampleRate = onErrorSampleRate ?? DefaultValues.onErrorSampleRate
        self.maskAllText = maskAllText ?? DefaultValues.maskAllText
        self.maskAllImages = maskAllImages ?? DefaultValues.maskAllImages
        self.enableViewRendererV2 = enableViewRendererV2 ?? DefaultValues.enableViewRendererV2
        self.enableFastViewRendering = enableFastViewRendering ?? DefaultValues.enableFastViewRendering
        self.maskedViewClasses = maskedViewClasses ?? DefaultValues.maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses ?? DefaultValues.unmaskedViewClasses
        self.quality = quality ?? DefaultValues.quality
        self.sdkInfo = sdkInfo ?? DefaultValues.sdkInfo
        self.frameRate = frameRate ?? DefaultValues.frameRate
        self.errorReplayDuration = errorReplayDuration ?? DefaultValues.errorReplayDuration
        self.sessionSegmentDuration = sessionSegmentDuration ?? DefaultValues.sessionSegmentDuration
        self.maximumDuration = maximumDuration ?? DefaultValues.maximumDuration
        
        super.init()
    }
}
// swiftlint:enable file_length
