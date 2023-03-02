#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryDsn, SentryMeasurementValue, SentryHttpStatusCodeRange;

NS_SWIFT_NAME(Options)
@interface SentryOptions : NSObject

/**
 * The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
 * not send any events.
 */
@property (nullable, nonatomic, strong) NSString *dsn;

/**
 * The parsed internal DSN.
 */
@property (nullable, nonatomic, strong) SentryDsn *parsedDsn;

/**
 * Turns debug mode on or off. If debug is enabled SDK will attempt to print out useful debugging
 * information if something goes wrong. Default is disabled.
 */
@property (nonatomic, assign) BOOL debug;

/**
 * Minimum LogLevel to be used if debug is enabled. Default is debug.
 */
@property (nonatomic, assign) SentryLevel diagnosticLevel;

/**
 * This property will be filled before the event is sent.
 */
@property (nullable, nonatomic, copy) NSString *releaseName;

/**
 * The distribution of the application.
 *
 * @discussion Distributions are used to disambiguate build or deployment variants of the same
 * release of an application. For example, the dist can be the build number of an Xcode build.
 *
 */
@property (nullable, nonatomic, copy) NSString *dist;

/**
 * The environment used for this event. Default value is "production".
 */
@property (nonatomic, copy) NSString *environment;

/**
 * Specifies wether this SDK should send events to Sentry. If set to NO events will be
 * dropped in the client and not sent to Sentry. Default is YES.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Controls the flush duration when calling ``SentrySDK/close``.
 */
@property (nonatomic, assign) NSTimeInterval shutdownTimeInterval;

/**
 * When enabled, the SDK sends crashes to Sentry. Default value is YES.
 *
 * Disabling this feature disables the ``SentryWatchdogTerminationTrackingIntegration``, cause the
 * ``SentryWatchdogTerminationTrackingIntegration`` would falsely report every crash as watchdog
 * termination.
 */
@property (nonatomic, assign) BOOL enableCrashHandler;

/**
 * How many breadcrumbs do you want to keep in memory?
 * Default is 100.
 */
@property (nonatomic, assign) NSUInteger maxBreadcrumbs;

/**
 * When enabled, the SDK adds breadcrumbs for each network request. Default value is
 * <code>YES</code>. As this feature uses swizzling, disabling <code>enableSwizzling</code> also
 * disables this feature.
 *
 * @discussion If you want to enable or disable network tracking for performance monitoring, please
 * use <code>enableNetworkTracking</code> instead.
 */
@property (nonatomic, assign) BOOL enableNetworkBreadcrumbs;

/**
 * The maximum number of envelopes to keep in cache. Default is 30.
 */
@property (nonatomic, assign) NSUInteger maxCacheItems;

/**
 * This block can be used to modify the event before it will be serialized and
 * sent
 */
@property (nullable, nonatomic, copy) SentryBeforeSendEventCallback beforeSend;

/**
 * This block can be used to modify the event before it will be serialized and
 * sent
 */
@property (nullable, nonatomic, copy) SentryBeforeBreadcrumbCallback beforeBreadcrumb;

/**
 * This gets called shortly after the initialization of the SDK when the last program execution
 * terminated with a crash. It is not guaranteed that this is called on the main thread.
 *
 * @discussion This callback is only executed once during the entire run of the program to avoid
 * multiple callbacks if there are multiple crash events to send. This can happen when the program
 * terminates with a crash before the SDK can send the crash event. You can look into beforeSend if
 * you prefer a callback for every event.
 */
@property (nullable, nonatomic, copy) SentryOnCrashedLastRunCallback onCrashedLastRun;

/**
 * Array of integrations to install.
 */
@property (nullable, nonatomic, copy) NSArray<NSString *> *integrations;

/**
 * Array of default integrations. Will be used if integrations are nil
 */
+ (NSArray<NSString *> *)defaultIntegrations;

/**
 * Indicates the percentage of events being sent to Sentry. Setting this to 0 discards all
 * events, 1.0 or NIL sends all events, 0.01 collects 1% of all events. The default is 1. The value
 * needs to be >= 0.0 and <= 1.0. When setting a value out of range  the SDK sets it to the default
 * of 1.0.
 */
@property (nullable, nonatomic, copy) NSNumber *sampleRate;

/**
 * Whether to enable automatic session tracking or not. Default is YES.
 */
@property (nonatomic, assign) BOOL enableAutoSessionTracking;

/**
 * Whether to enable Watchdog Termination tracking or not. Default is YES.
 *
 * This feature requires the ``SentryCrashIntegration`` being enabled, cause otherwise it would
 * falsely report every crash as watchdog termination.
 */
@property (nonatomic, assign) BOOL enableWatchdogTerminationTracking;

/**
 * The interval to end a session if the App goes to the background.
 */
@property (nonatomic, assign) NSUInteger sessionTrackingIntervalMillis;

/**
 * When enabled, stack traces are automatically attached to all messages logged. Stack traces are
 * always attached to exceptions but when this is set stack traces are also sent with messages.
 * Stack traces are only attached for the current thread.
 *
 * This feature is enabled by default.
 */
@property (nonatomic, assign) BOOL attachStacktrace;

/**
 * Attention: This is an experimental feature. Turning this feature on can have an impact on
 * the grouping of your issues.
 *
 * When enabled, the SDK stitches stack traces of asynchronous code together.
 *
 * This feature is disabled by default.
 */
@property (nonatomic, assign) BOOL stitchAsyncCode;

/**
 * The maximum size for each attachment in bytes. Default is 20 MiB / 20 * 1024 * 1024 bytes.
 *
 * Please also check the maximum attachment size of relay to make sure your attachments don't get
 * discarded there: https://docs.sentry.io/product/relay/options/
 */
@property (nonatomic, assign) NSUInteger maxAttachmentSize;

/**
 * When enabled, the SDK sends personal identifiable along with events. The default is
 * <code>NO</code>.
 *
 * @discussion When the user of an event doesn't contain an IP address, and this flag is
 * <code>YES</code>, the SDK sets it to <code>{{auto}}</code> to instruct the server to use the
 * connection IP address as the user address. Due to backward compatibility concerns, Sentry set the
 * IP address to <code>{{auto}}</code> out of the box for Cocoa. If you want to stop Sentry from
 * using the connections IP address, you have to enable Prevent Storing of IP Addresses in your
 * project settings in Sentry.
 */
@property (nonatomic, assign) BOOL sendDefaultPii;

/**
 * When enabled, the SDK tracks performance for UIViewController subclasses and HTTP requests
 * automatically. It also measures the app start and slow and frozen frames. The default is
 * <code>YES</code>. Note: Performance Monitoring must be enabled for this flag to take effect. See:
 * https://docs.sentry.io/platforms/apple/performance/
 */
@property (nonatomic, assign) BOOL enableAutoPerformanceTracing;

#if SENTRY_HAS_UIKIT
/**
 * When enabled, the SDK tracks performance for UIViewController subclasses. The default is
 * <code>YES</code>.
 */
@property (nonatomic, assign) BOOL enableUIViewControllerTracing;

/**
 * Automatically attaches a screenshot when capturing an error or exception.
 *
 * Default value is <code>NO</code>
 */
@property (nonatomic, assign) BOOL attachScreenshot;

/**
 * This feature is EXPERIMENTAL.
 *
 * Automatically attaches a textual representation of the view hierarchy when capturing an error
 * event.
 *
 * Default value is <code>NO</code>
 */
@property (nonatomic, assign) BOOL attachViewHierarchy;

/**
 * When enabled, the SDK creates transactions for UI events like buttons clicks, switch toggles,
 * and other ui elements that uses UIControl `sendAction:to:forEvent:`.
 */
@property (nonatomic, assign) BOOL enableUserInteractionTracing;

/**
 * How long an idle transaction waits for new children after all its child spans finished. Only UI
 * event transactions are idle transactions. The default is 3 seconds.
 */
@property (nonatomic, assign) NSTimeInterval idleTimeout;

/**
 * This feature is EXPERIMENTAL.
 *
 * Report pre-warmed app starts by dropping the first app start spans if pre-warming paused during
 * these steps. This approach will shorten the app start duration, but it represents the duration a
 * user has to wait after clicking the app icon until the app is responsive.
 *
 * You can filter for different app start types in Discover with app_start_type:cold.prewarmed,
 * app_start_type:warm.prewarmed, app_start_type:cold, and app_start_type:warm.
 *
 * Default value is <code>NO</code>
 */
@property (nonatomic, assign) BOOL enablePreWarmedAppStartTracing;

#endif

/**
 * When enabled, the SDK tracks performance for HTTP requests if auto performance tracking and
 * enableSwizzling are enabled. The default is <code>YES</code>.
 *
 * @discussion If you want to enable or disable network breadcrumbs, please use
 * <code>enableNetworkBreadcrumbs</code> instead.
 */
@property (nonatomic, assign) BOOL enableNetworkTracking;

/**
 * When enabled, the SDK tracks performance for file IO reads and writes with NSData if auto
 * performance tracking and enableSwizzling are enabled. The default is <code>YES</code>.
 */
@property (nonatomic, assign) BOOL enableFileIOTracing;

/**
 * Indicates the percentage of the tracing data that is collected. Setting this to 0 or NIL discards
 * all trace data, 1.0 collects all trace data, 0.01 collects 1% of all trace data. The default is
 * 0. The value needs to be >= 0.0 and <= 1.0. When setting a value out of range  the SDK sets it to
 * the default of 0.
 */
@property (nullable, nonatomic, strong) NSNumber *tracesSampleRate;

/**
 * A callback to a user defined traces sampler function. Returning 0 or NIL discards all trace
 * data, 1.0 collects all trace data, 0.01 collects 1% of all trace data. The sample rate needs to
 * be >= 0.0 and <= 1.0 or NIL. When returning a value out of range the SDK uses the default of 0.
 */
@property (nullable, nonatomic) SentryTracesSamplerCallback tracesSampler;

/**
 * If tracing should be enabled or not. Returns YES if either a tracesSampleRate > 0 and <=1 or a
 * tracesSampler is set otherwise NO.
 */
@property (nonatomic, assign, readonly) BOOL isTracingEnabled;

/**
 * A list of string prefixes of framework names that belong to the app. This option takes precedence
 * over inAppExcludes. Per default this contains CFBundleExecutable to mark it as inApp.
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *inAppIncludes;

/**
 * Adds an item to the list of inAppIncludes.
 *
 * @param inAppInclude The prefix of the framework name.
 */
- (void)addInAppInclude:(NSString *)inAppInclude;

/**
 * A list of string prefixes of framework names that do not belong to the app, but rather to
 * third-party frameworks. Frameworks considered not part of the app will be hidden from stack
 * traces by default.
 *
 * This option can be overridden using inAppIncludes.
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *inAppExcludes;

/**
 * Adds an item to the list of inAppExcludes.
 *
 * @param inAppExclude The prefix of the frameworks name.
 */
- (void)addInAppExclude:(NSString *)inAppExclude;

/**
 * Set as delegate on the NSURLSession used for all network data-transfer tasks performed by Sentry.
 */
@property (nullable, nonatomic, weak) id<NSURLSessionDelegate> urlSessionDelegate;

/**
 * Wether the SDK should use swizzling or not. Default is YES.
 *
 * @discussion When turned off the following features are disabled: breadcrumbs for touch events and
 * navigation with UIViewControllers, automatic instrumentation for UIViewControllers, automatic
 * instrumentation for HTTP requests, automatic instrumentation for file IO with NSData, and
 * automatically added sentry-trace header to HTTP requests for distributed tracing.
 */
@property (nonatomic, assign) BOOL enableSwizzling;

/**
 * When enabled, the SDK tracks the performance of Core Data operations. It requires enabling
 * performance monitoring. The default is <code>YES</code>.
 * @see <https://docs.sentry.io/platforms/apple/performance/>
 */
@property (nonatomic, assign) BOOL enableCoreDataTracing;

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * This feature is experimental. Profiling is not supported on watchOS or tvOS.
 *
 * Indicates the percentage profiles being sampled out of the sampled transactions.
 *
 * The default is 0. The value needs to be >= 0.0 and <= 1.0. When setting a value out of range
 * the SDK sets it to the default of 0.
 *
 * This property is dependent on `tracesSampleRate` -- if `tracesSampleRate` is 0 (default),
 * no profiles will be collected no matter what this property is set to. This property is
 * used to undersample profiles *relative to* `tracesSampleRate`.
 */
@property (nullable, nonatomic, strong) NSNumber *profilesSampleRate;

/**
 * This feature is experimental. Profiling is not supported on watchOS or tvOS.
 *
 * A callback to a user defined profiles sampler function. This is similar to setting
 * `profilesSampleRate`, but instead of a static value, the callback function will be called to
 * determine the sample rate.
 */
@property (nullable, nonatomic) SentryTracesSamplerCallback profilesSampler;

/**
 * If profiling should be enabled or not. Returns YES if either a profilesSampleRate > 0 and
 * <=1 or a profilesSampler is set otherwise NO.
 */
@property (nonatomic, assign, readonly) BOOL isProfilingEnabled;

/**
 * DEPRECATED: Use `profilesSampleRate` instead. Setting `enableProfiling` to YES is the equivalent
 * of setting `profilesSampleRate` to `1.0`. If `profilesSampleRate` is set, it will take precedence
 * over this setting.
 *
 * Whether to enable the sampling profiler. Default is NO.
 * @note This is a beta feature that is currently not available to all Sentry customers. This
 * feature is not supported on watchOS or tvOS.
 */
@property (nonatomic, assign) BOOL enableProfiling DEPRECATED_MSG_ATTRIBUTE(
    "Use profilesSampleRate or profilesSampler instead. This property will be removed in a future "
    "version of the SDK");
#endif

/**
 * Whether to send client reports, which contain statistics about discarded events. The default is
 * <code>YES</code>.
 *
 * @see <https://develop.sentry.dev/sdk/client-reports/>
 */
@property (nonatomic, assign) BOOL sendClientReports;

/**
 * When enabled, the SDK tracks when the application stops responding for a specific amount of
 * time defined by the `appHangsTimeoutInterval` option. The default is
 * <code>YES</code>
 */
@property (nonatomic, assign) BOOL enableAppHangTracking;

/**
 * The minimum amount of time an app should be unresponsive to be classified as an App Hanging.
 * The actual amount may be a little longer.
 * Avoid using values lower than 100ms, which may cause a lot of app hangs events being transmitted.
 * The default value is 2 seconds.
 */
@property (nonatomic, assign) NSTimeInterval appHangTimeoutInterval;

/**
 * When enabled, the SDK adds breadcrumbs for various system events. Default value is YES.
 */
@property (nonatomic, assign) BOOL enableAutoBreadcrumbTracking;

/**
 * An array of hosts or regexes that determines if outgoing HTTP requests will get
 * extra `trace_id` and `baggage` headers added.
 *
 * This array can contain instances of NSString which should match the URL (using `contains`),
 * and instances of NSRegularExpression, which will be used to check the whole URL.
 *
 * The default value adds the header to all outgoing requests.
 *
 * @see https://docs.sentry.io/platforms/apple/configuration/options/#trace-propagation-targets
 */
@property (nonatomic, retain) NSArray *tracePropagationTargets;

/**
 * When enabled, the SDK captures HTTP Client errors.
 * This feature requires enableSwizzling enabled as well, Default value is YES.
 */
@property (nonatomic, assign) BOOL enableCaptureFailedRequests;

/**
 * The SDK will only capture HTTP Client errors if the HTTP Response status code is within the
 * defined range.
 *
 * Defaults to 500 - 599.
 */
@property (nonatomic, strong) NSArray<SentryHttpStatusCodeRange *> *failedRequestStatusCodes;

/**
 * An array of hosts or regexes that determines if HTTP Client errors will be automatically
 * captured.
 *
 * This array can contain instances of NSString which should match the URL (using `contains`),
 * and instances of NSRegularExpression, which will be used to check the whole URL.
 *
 * The default value automatically captures HTTP Client errors of all outgoing requests.
 */
@property (nonatomic, strong) NSArray *failedRequestTargets;

#if SENTRY_HAS_METRIC_KIT

/**
 * ATTENTION: This is an experimental feature.
 *
 * This feature is disabled by default. When enabled, the SDK sends
 * ``MXDiskWriteExceptionDiagnostic``, ``MXCPUExceptionDiagnostic`` and ``MXHangDiagnostic``  to
 * Sentry. The SDK supports this feature from iOS 15 and later and macOS 12 and later because, on
 * these versions, MetricKit delivers diagnostic reports immediately, which allows the Sentry SDK to
 * apply the current data from the scope.
 */
@property (nonatomic, assign) BOOL enableMetricKit API_AVAILABLE(
    ios(15.0), macos(12.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);

#endif

@end

NS_ASSUME_NONNULL_END
