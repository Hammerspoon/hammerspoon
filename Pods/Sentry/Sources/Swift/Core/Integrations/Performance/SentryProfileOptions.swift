import Foundation

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

/// An object containing configuration for the Sentry profiler.
/// - warning: Continuous profiling is an experimental feature and may still contain bugs.
/// - note: If either `SentryOptions.profilesSampleRate` or `SentryOptions.profilesSampler` are
/// set to a non-nil value such that transaction-based profiling is being used, these settings
/// will have no effect, nor will `SentrySDK.startProfiler()` or `SentrySDK.stopProfiler()`.
/// - note: Profiling is automatically disabled if a thread sanitizer is attached.
@objcMembers
public class SentryProfileOptions: NSObject {
    /// Different modes for starting and stopping the profiler.
    @objc public enum SentryProfileLifecycle: Int {
        /// Profiling is controlled manually, and is independent of transactions & spans. Developers
        /// must use`SentrySDK.startProfiler()` and `SentrySDK.stopProfiler()` to manage the profile
        /// session. If the session is sampled, `SentrySDK.startProfiler()` will always start
        /// profiling.
        /// - warning: Continuous profiling is an experimental feature and may still contain bugs.
        /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
        case manual
        
        /// Profiling is automatically started when there is at least 1 active root span, and
        /// automatically stopped when there are 0 root spans.
        /// - warning: Continuous profiling is an experimental feature and may still contain bugs.
        /// - note: This mode only works if tracing is enabled.
        /// - note: Profiling respects both `SentryProfileOptions.profileSessionSampleRate` and
        /// the existing sampling configuration for tracing
        /// (`SentryOptions.tracesSampleRate`/`SentryOptions.tracesSampler`). Sampling will be
        /// re-evaluated on a per root span basis.
        /// - note: If there are multiple overlapping root spans, where some are sampled and some or
        /// not, profiling will continue until the end of the last sampled root span. Profiling data
        /// will not be linked with spans that are not sampled.
        /// - note: When the last root span finishes, the profiler will continue running until the
        /// end of the current timed interval. If a new root span starts before this interval
        /// completes, the profiler will instead continue running until the next root span stops, at
        /// which time it will attempt to stop again in the same way.
        /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
        case trace
    }
    
    /// The mode to use for starting and stopping the profiler, either manually or automatically.
    /// - warning: Continuous profiling is an experimental feature and may still contain bugs.
    /// - note: Default: `SentryProfileLifecycleManual`.
    /// - note: If either `SentryOptions.profilesSampleRate` or `SentryOptions.profilesSampler` are
    /// set to a non-nil value such that transaction-based profiling is being used, then setting
    /// this property has no effect.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    public var lifecycle: SentryProfileLifecycle = .manual
    
    /// The % of user sessions in which to enable profiling.
    /// - warning: Continuous profiling is an experimental feature and may still contain bugs.
    /// - note: The decision whether or not to sample profiles is computed using this sample rate
    /// when the SDK is started, and applies to any requests to start the profiler–regardless of
    /// `lifecycle`– until the app resigns its active status. It is then reevaluated on subsequent
    /// foreground events. The duration of time that a sample decision prevails between
    /// launch/foreground and background is referred to as a profile session.
    /// - note: Backgrounding and foregrounding the app starts a new user session and sampling is
    /// re-evaluated. If there is no active trace when the app is backgrounded, profiling stops
    /// before the app backgrounds. If there is an active trace and profiling is in-flight when the
    /// app is foregrounded again, the same profiling session should continue until the last root
    /// span in that trace finishes — this means that the re-evaluated sample rate does not actually
    /// take effect until the profiler is started again.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    public var sessionSampleRate: Float = 0

    /// Start the profiler as early as possible during the app lifecycle to capture more activity
    /// during your app's launch.
    /// - warning: Continuous profiling is an experimental feature and may still contain bugs.
    /// - note: `sessionSampleRate` is evaluated on the previous launch and only takes effect when
    /// app start profiling activates on the next launch.
    /// - note: If `lifecycle` is `manual`, profiling is started automatically on startup, but you
    /// must manually call `SentrySDK.stopProfiler()` whenever you app startup to be complete. If
    /// `lifecycle` is `trace`, profiling is started automatically on startup, and will
    /// automatically be stopped when the root span that is associated with app startup ends.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    public var profileAppStarts: Bool = false
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
