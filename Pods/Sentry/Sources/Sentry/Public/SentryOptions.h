#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryDsn, SentryMeasurementValue, SentryHttpStatusCodeRange, SentryScope,
    SentryReplayOptions;
@class SentryExperimentalOptions;

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
 * information if something goes wrong.
 * @note Default is @c NO.
 */
@property (nonatomic, assign) BOOL debug;

/**
 * Minimum LogLevel to be used if debug is enabled.
 * @note Default is @c kSentryLevelDebug.
 */
@property (nonatomic, assign) SentryLevel diagnosticLevel;

/**
 * This property will be filled before the event is sent.
 */
@property (nullable, nonatomic, copy) NSString *releaseName;

/**
 * The distribution of the application.
 * @discussion Distributions are used to disambiguate build or deployment variants of the same
 * release of an application. For example, the @c dist can be the build number of an Xcode build.
 *
 */
@property (nullable, nonatomic, copy) NSString *dist;

/**
 * The environment used for this event.
 * @note Default value is @c @"production".
 */
@property (nonatomic, copy) NSString *environment;

/**
 * Specifies wether this SDK should send events to Sentry. If set to @c NO events will be
 * dropped in the client and not sent to Sentry. Default is @c YES.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Controls the flush duration when calling @c SentrySDK/close .
 */
@property (nonatomic, assign) NSTimeInterval shutdownTimeInterval;

/**
 * When enabled, the SDK sends crashes to Sentry.
 * @note Disabling this feature disables the @c SentryWatchdogTerminationTrackingIntegration ,
 * because
 * @c SentryWatchdogTerminationTrackingIntegration would falsely report every crash as watchdog
 * termination.
 * @note Default value is @c YES .
 * @note Crash reporting is automatically disabled if a debugger is attached.
 */
@property (nonatomic, assign) BOOL enableCrashHandler;

#if !TARGET_OS_WATCH

/**
 * When enabled, the SDK reports SIGTERM signals to Sentry.
 *
 * It's crucial for developers to understand that the OS sends a SIGTERM to their app as a prelude
 * to a graceful shutdown, before resorting to a SIGKILL. This SIGKILL, which your app can't catch
 * or ignore, is a direct order to terminate your app's process immediately. Developers should be
 * aware that their app can receive a SIGTERM in various scenarios, such as  CPU or disk overuse,
 * watchdog terminations, or when the OS updates your app.
 *
 * @note The default value is @c NO.
 */
@property (nonatomic, assign) BOOL enableSigtermReporting;

#endif // !TARGET_OS_WATCH

/**
 * How many breadcrumbs do you want to keep in memory?
 * @note Default is @c 100 .
 */
@property (nonatomic, assign) NSUInteger maxBreadcrumbs;

/**
 * When enabled, the SDK adds breadcrumbs for each network request. As this feature uses swizzling,
 * disabling @c enableSwizzling also disables this feature.
 * @discussion If you want to enable or disable network tracking for performance monitoring, please
 * use @c enableNetworkTracking instead.
 * @note Default value is @c YES .
 */
@property (nonatomic, assign) BOOL enableNetworkBreadcrumbs;

/**
 * The maximum number of envelopes to keep in cache.
 * @note Default is @c 30 .
 */
@property (nonatomic, assign) NSUInteger maxCacheItems;

/**
 * This block can be used to modify the event before it will be serialized and sent.
 */
@property (nullable, nonatomic, copy) SentryBeforeSendEventCallback beforeSend;

/**
 * Use this callback to drop or modify a span before the SDK sends it to Sentry. Return @c nil to
 * drop the span.
 */
@property (nullable, nonatomic, copy) SentryBeforeSendSpanCallback beforeSendSpan;

/**
 * This block can be used to modify the event before it will be serialized and sent.
 */
@property (nullable, nonatomic, copy) SentryBeforeBreadcrumbCallback beforeBreadcrumb;

/**
 * You can use this callback to decide if the SDK should capture a screenshot or not. Return @c true
 * if the SDK should capture a screenshot, return @c false if not. This callback doesn't work for
 * crashes.
 */
@property (nullable, nonatomic, copy) SentryBeforeCaptureScreenshotCallback beforeCaptureScreenshot;

/**
 * A block called shortly after the initialization of the SDK when the last program execution
 * terminated with a crash.
 * @discussion This callback is only executed once during the entire run of the program to avoid
 * multiple callbacks if there are multiple crash events to send. This can happen when the program
 * terminates with a crash before the SDK can send the crash event. You can look into @c beforeSend
 * if you prefer a callback for every event.
 * @warning It is not guaranteed that this is called on the main thread.
 * @note Crash reporting is automatically disabled if a debugger is attached.
 */
@property (nullable, nonatomic, copy) SentryOnCrashedLastRunCallback onCrashedLastRun;

/**
 * Array of integrations to install.
 */
@property (nullable, nonatomic, copy) NSArray<NSString *> *integrations;

/**
 * Array of default integrations. Will be used if @c integrations is @c nil .
 */
+ (NSArray<NSString *> *)defaultIntegrations;

/**
 * Indicates the percentage of events being sent to Sentry.
 * @discussion Specifying @c 0 discards all events, @c 1.0 or @c nil sends all events, @c 0.01
 * collects 1% of all events.
 * @note The value needs to be >= @c 0.0 and \<= @c 1.0. When setting a value out of range the SDK
 * sets it to the default of @c 1.0.
 * @note The default is @c 1 .
 */
@property (nullable, nonatomic, copy) NSNumber *sampleRate;

/**
 * Whether to enable automatic session tracking or not.
 * @note Default is @c YES.
 */
@property (nonatomic, assign) BOOL enableAutoSessionTracking;

/**
 * Whether to attach the top level `operationName` node of HTTP json requests to HTTP breadcrumbs
 * @note Default is @c NO.
 */
@property (nonatomic, assign) BOOL enableGraphQLOperationTracking;

/**
 * Whether to enable Watchdog Termination tracking or not.
 * @note This feature requires the @c SentryCrashIntegration being enabled, otherwise it would
 * falsely report every crash as watchdog termination.
 * @note Default is @c YES.
 */
@property (nonatomic, assign) BOOL enableWatchdogTerminationTracking;

/**
 * The interval to end a session after the App goes to the background.
 * @note The default is 30 seconds.
 */
@property (nonatomic, assign) NSUInteger sessionTrackingIntervalMillis;

/**
 * When enabled, stack traces are automatically attached to all messages logged. Stack traces are
 * always attached to exceptions but when this is set stack traces are also sent with messages.
 * Stack traces are only attached for the current thread.
 * @note This feature is enabled by default.
 */
@property (nonatomic, assign) BOOL attachStacktrace;

/**
 * The maximum size for each attachment in bytes.
 * @note Default is 20 MiB (20 ✕ 1024 ✕ 1024 bytes).
 * @note Please also check the maximum attachment size of relay to make sure your attachments don't
 * get discarded there:
 *  https://docs.sentry.io/product/relay/options/
 */
@property (nonatomic, assign) NSUInteger maxAttachmentSize;

/**
 * When enabled, the SDK sends personal identifiable along with events.
 * @note The default is @c NO .
 * @discussion When the user of an event doesn't contain an IP address, and this flag is
 * @c YES, the SDK sets it to @c {{auto}} to instruct the server to use the
 * connection IP address as the user address. Due to backward compatibility concerns, Sentry set the
 * IP address to @c {{auto}} out of the box for Cocoa. If you want to stop Sentry from
 * using the connections IP address, you have to enable Prevent Storing of IP Addresses in your
 * project settings in Sentry.
 */
@property (nonatomic, assign) BOOL sendDefaultPii;

/**
 * When enabled, the SDK tracks performance for UIViewController subclasses and HTTP requests
 * automatically. It also measures the app start and slow and frozen frames.
 * @note The default is @c YES .
 * @note Performance Monitoring must be enabled for this flag to take effect. See:
 * https://docs.sentry.io/platforms/apple/performance/
 */
@property (nonatomic, assign) BOOL enableAutoPerformanceTracing;

/**
 * @warning This is an experimental feature and may still have bugs.
 *
 * Sentry works on reworking the whole performance offering with the code Mobile Starfish, which
 * aims to provide better insights into the performance of mobile apps and highlight clear actions
 * to improve app performance to developers. This feature flag enables experimental features that
 * impact the v1 performance offering and would require a major version update. Sentry aims to
 * include most features in the next major by default.
 */
@property (nonatomic, assign) BOOL enablePerformanceV2;

/**
 * A block that configures the initial scope when starting the SDK.
 * @discussion The block receives a suggested default scope. You can either
 * configure and return this, or create your own scope instead.
 * @note The default simply returns the passed in scope.
 */
@property (nonatomic) SentryScope * (^initialScope)(SentryScope *);

#if SENTRY_UIKIT_AVAILABLE
/**
 * When enabled, the SDK tracks performance for UIViewController subclasses.
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 * @note The default is @c YES .
 */
@property (nonatomic, assign) BOOL enableUIViewControllerTracing;

/**
 * Automatically attaches a screenshot when capturing an error or exception.
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 * @note Default value is @c NO .
 */
@property (nonatomic, assign) BOOL attachScreenshot;

/**
 * @warning This is an experimental feature and may still have bugs.
 * @brief Automatically attaches a textual representation of the view hierarchy when capturing an
 * error event.
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 * @note Default value is @c NO .
 */
@property (nonatomic, assign) BOOL attachViewHierarchy;

/**
 * When enabled, the SDK creates transactions for UI events like buttons clicks, switch toggles,
 * and other ui elements that uses UIControl @c sendAction:to:forEvent:
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 * @note Default value is @c YES .
 */
@property (nonatomic, assign) BOOL enableUserInteractionTracing;

/**
 * How long an idle transaction waits for new children after all its child spans finished. Only UI
 * event transactions are idle transactions.
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 * @note The default is 3 seconds.
 */
@property (nonatomic, assign) NSTimeInterval idleTimeout;

/**
 * Report pre-warmed app starts by dropping the first app start spans if pre-warming paused
 * during these steps. This approach will shorten the app start duration, but it represents the
 * duration a user has to wait after clicking the app icon until the app is responsive.
 *
 * @note You can filter for different app start types in Discover with
 * @c app_start_type:cold.prewarmed ,
 * @c app_start_type:warm.prewarmed , @c app_start_type:cold , and @c app_start_type:warm .
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 * @note Default value is @c NO .
 */
@property (nonatomic, assign) BOOL enablePreWarmedAppStartTracing;

#endif // SENTRY_UIKIT_AVAILABLE

/**
 * When enabled, the SDK tracks performance for HTTP requests if auto performance tracking and
 * @c enableSwizzling are enabled.
 * @note The default is @c YES .
 * @discussion If you want to enable or disable network breadcrumbs, please use
 * @c enableNetworkBreadcrumbs instead.
 */
@property (nonatomic, assign) BOOL enableNetworkTracking;

/**
 * When enabled, the SDK tracks performance for file IO reads and writes with NSData if auto
 * performance tracking and enableSwizzling are enabled.
 * @note The default is @c YES .
 */
@property (nonatomic, assign) BOOL enableFileIOTracing;

/**
 * Indicates whether tracing should be enabled.
 * @discussion Enabling this sets @c tracesSampleRate to @c 1 if both @c tracesSampleRate and
 * @c tracesSampler are @c nil. Changing either @c tracesSampleRate or @c tracesSampler to a value
 * other then @c nil will enable this in case this was never changed before.
 */
@property (nonatomic)
    BOOL enableTracing DEPRECATED_MSG_ATTRIBUTE("Use tracesSampleRate or tracesSampler instead");

/**
 * Indicates the percentage of the tracing data that is collected.
 * @discussion Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
 * @c 0.01 collects 1% of all trace data.
 * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
 * to the default.
 * @note The default is @c 0 .
 */
@property (nullable, nonatomic, strong) NSNumber *tracesSampleRate;

/**
 * A callback to a user defined traces sampler function.
 * @discussion Specifying @c 0 or @c nil discards all trace data, @c 1.0 collects all trace data,
 * @c 0.01 collects 1% of all trace data.
 * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
 * to the default of @c 0 .
 * @note If @c enableAppLaunchProfiling is @c YES , this function will be called during SDK start
 * with @c SentrySamplingContext.forNextAppLaunch set to @c YES, and the result will be persisted to
 * disk for use on the next app launch.
 */
@property (nullable, nonatomic) SentryTracesSamplerCallback tracesSampler;

/**
 * If tracing is enabled or not.
 * @discussion @c YES if @c tracesSampleRateis > @c 0 and \<= @c 1
 * or a @c tracesSampler is set, otherwise @c NO.
 */
@property (nonatomic, assign, readonly) BOOL isTracingEnabled;

/**
 * A list of string prefixes of framework names that belong to the app.
 * @note This option takes precedence over @c inAppExcludes.
 * @note By default, this contains @c CFBundleExecutable to mark it as "in-app".
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *inAppIncludes;

/**
 * Adds an item to the list of @c inAppIncludes.
 * @param inAppInclude The prefix of the framework name.
 */
- (void)addInAppInclude:(NSString *)inAppInclude;

/**
 * A list of string prefixes of framework names that do not belong to the app, but rather to
 * third-party frameworks.
 * @note By default, frameworks considered not part of the app will be hidden from stack
 * traces.
 * @note This option can be overridden using @c inAppIncludes.
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *inAppExcludes;

/**
 * Adds an item to the list of @c inAppExcludes.
 * @param inAppExclude The prefix of the frameworks name.
 */
- (void)addInAppExclude:(NSString *)inAppExclude;

/**
 * Set as delegate on the @c NSURLSession used for all network data-transfer tasks performed by
 * Sentry.
 *
 * @discussion The SDK ignores this option when using @c urlSession.
 */
@property (nullable, nonatomic, weak) id<NSURLSessionDelegate> urlSessionDelegate;

/**
 * Use this property, so the transport uses this  @c NSURLSession with your configuration for
 * sending requests to Sentry.
 *
 * If not set, the SDK will create a new @c NSURLSession with @c [NSURLSessionConfiguration
 * ephemeralSessionConfiguration].
 *
 * @note Default is @c nil.
 */
@property (nullable, nonatomic, strong) NSURLSession *urlSession;

/**
 * Wether the SDK should use swizzling or not.
 * @discussion When turned off the following features are disabled: breadcrumbs for touch events and
 * navigation with @c UIViewControllers, automatic instrumentation for @c UIViewControllers,
 * automatic instrumentation for HTTP requests, automatic instrumentation for file IO with
 * @c NSData, and automatically added sentry-trace header to HTTP requests for distributed tracing.
 * @note Default is @c YES.
 */
@property (nonatomic, assign) BOOL enableSwizzling;

/**
 * An array of class names to ignore for swizzling.
 *
 * @discussion The SDK checks if a class name of a class to swizzle contains a class name of this
 * array. For example, if you add MyUIViewController to this list, the SDK excludes the following
 * classes from swizzling: YourApp.MyUIViewController, YourApp.MyUIViewControllerA,
 * MyApp.MyUIViewController.
 * We can't use an @c NSArray<Class>  here because we use this as a workaround for which users have
 * to pass in class names that aren't available on specific iOS versions. By using @c
 * NSArray<NSString *>, users can specify unavailable class names.
 *
 * @note Default is an empty array.
 */
@property (nonatomic, strong) NSSet<NSString *> *swizzleClassNameExcludes;

/**
 * When enabled, the SDK tracks the performance of Core Data operations. It requires enabling
 * performance monitoring. The default is @c YES.
 * @see <https://docs.sentry.io/platforms/apple/performance/>
 */
@property (nonatomic, assign) BOOL enableCoreDataTracing;

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * @warning This is an experimental feature and may still have bugs.
 * Set to @c YES to run the profiler as early as possible in an app launch, before you would
 * normally have the opportunity to call @c SentrySDK.start . If enabled, the @c tracesSampleRate
 * and @c profilesSampleRate are persisted to disk and read on the next app launch to decide whether
 * to profile that launch.
 * @see @c tracesSampler and @c profilesSampler for more information on how they work for this
 * feature.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 */
@property (nonatomic, assign) BOOL enableAppLaunchProfiling;

/**
 * @note Profiling is not supported on watchOS or tvOS.
 * Indicates the percentage profiles being sampled out of the sampled transactions.
 * @note The default is @c 0.
 * @note The value needs to be >= @c 0.0 and \<= @c 1.0. When setting a value out of range
 * the SDK sets it to the default of @c 0.
 * This property is dependent on @c tracesSampleRate -- if @c tracesSampleRate is @c 0 (default),
 * no profiles will be collected no matter what this property is set to. This property is
 * used to undersample profiles *relative to* @c tracesSampleRate .
 * @note Setting this value to @c nil enables an experimental new profiling mode, called continuous
 * profiling. This allows you to start and stop a profiler any time with @c SentrySDK.startProfiler
 * and @c SentrySDK.stopProfiler, which can run with no time limit, periodically uploading profiling
 * data. You can also set @c SentryOptions.enableAppLaunchProfiling to have the profiler start on
 * app launch; there is no automatic stop, you must stop it manually at some later time if you
 * choose to do so. Sampling rates do not apply to continuous profiles, including those
 * automatically started for app launches. If you wish to sample them, you must do so at the
 * callsites where you use the API or configure launch profiling. Continuous profiling is not
 * automatically started for performance transactions as was the previous version of profiling.
 * @warning The new continuous profiling mode is experimental and may still contain bugs.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 */
@property (nullable, nonatomic, strong) NSNumber *profilesSampleRate;

/**
 * @note Profiling is not supported on watchOS or tvOS.
 * A callback to a user defined profiles sampler function. This is similar to setting
 * @c profilesSampleRate  but instead of a static value, the callback function will be called to
 * determine the sample rate.
 * @note If @c enableAppLaunchProfiling is @c YES , this function will be called during SDK start
 * with @c SentrySamplingContext.forNextAppLaunch set to @c YES, and the result will be persisted to
 * disk for use on the next app launch.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 */
@property (nullable, nonatomic) SentryTracesSamplerCallback profilesSampler;

/**
 * If profiling should be enabled or not.
 * @note Profiling is not supported on watchOS or tvOS.
 * @note This only returns whether or not trace-based profiling is enabled. If it is not, then
 * continuous profiling is effectively enabled, and calling SentrySDK.startProfiler will
 * successfully start a continuous profile.
 * @returns @c YES if either @c profilesSampleRate > @c 0 and \<= @c 1 , or @c profilesSampler is
 * set, otherwise @c NO.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 */
@property (nonatomic, assign, readonly) BOOL isProfilingEnabled;

/**
 * @brief Whether to enable the sampling profiler.
 * @note Profiling is not supported on watchOS or tvOS.
 * @deprecated Use @c profilesSampleRate instead. Setting @c enableProfiling to @c YES is the
 * equivalent of setting @c profilesSampleRate to @c 1.0  If @c profilesSampleRate is set, it will
 * take precedence over this setting.
 * @note Default is @c NO.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 */
@property (nonatomic, assign) BOOL enableProfiling DEPRECATED_MSG_ATTRIBUTE(
    "Use profilesSampleRate or profilesSampler instead. This property will be removed in a future "
    "version of the SDK");
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

/**
 * Whether to send client reports, which contain statistics about discarded events.
 * @note The default is @c YES.
 * @see <https://develop.sentry.dev/sdk/client-reports/>
 */
@property (nonatomic, assign) BOOL sendClientReports;

/**
 * When enabled, the SDK tracks when the application stops responding for a specific amount of
 * time defined by the @c appHangsTimeoutInterval option.
 * @note The default is @c YES
 * @note ANR tracking is automatically disabled if a debugger is attached.
 */
@property (nonatomic, assign) BOOL enableAppHangTracking;

/**
 * The minimum amount of time an app should be unresponsive to be classified as an App Hanging.
 * @note The actual amount may be a little longer.
 * @note Avoid using values lower than 100ms, which may cause a lot of app hangs events being
 * transmitted.
 * @note The default value is 2 seconds.
 */
@property (nonatomic, assign) NSTimeInterval appHangTimeoutInterval;

/**
 * When enabled, the SDK adds breadcrumbs for various system events.
 * @note Default value is @c YES.
 */
@property (nonatomic, assign) BOOL enableAutoBreadcrumbTracking;

/**
 * An array of hosts or regexes that determines if outgoing HTTP requests will get
 * extra @c trace_id and @c baggage headers added.
 * @discussion This array can contain instances of @c NSString which should match the URL (using
 * @c contains ), and instances of @c NSRegularExpression, which will be used to check the whole
 * URL.
 * @note The default value adds the header to all outgoing requests.
 * @see https://docs.sentry.io/platforms/apple/configuration/options/#trace-propagation-targets
 */
@property (nonatomic, retain) NSArray *tracePropagationTargets;

/**
 * When enabled, the SDK captures HTTP Client errors.
 * @note This feature requires @c enableSwizzling enabled as well.
 * @note Default value is @c YES.
 */
@property (nonatomic, assign) BOOL enableCaptureFailedRequests;

/**
 * The SDK will only capture HTTP Client errors if the HTTP Response status code is within the
 * defined range.
 * @note Defaults to 500 - 599.
 */
@property (nonatomic, strong) NSArray<SentryHttpStatusCodeRange *> *failedRequestStatusCodes;

/**
 * An array of hosts or regexes that determines if HTTP Client errors will be automatically
 * captured.
 * @discussion This array can contain instances of @c NSString which should match the URL (using
 * @c contains ), and instances of @c NSRegularExpression, which will be used to check the whole
 * URL.
 * @note The default value automatically captures HTTP Client errors of all outgoing requests.
 */
@property (nonatomic, strong) NSArray *failedRequestTargets;

#if SENTRY_HAS_METRIC_KIT

/**
 * Use this feature to enable the Sentry MetricKit integration.
 *
 * @brief When enabled, the SDK sends @c MXDiskWriteExceptionDiagnostic, @c MXCPUExceptionDiagnostic
 * and
 * @c MXHangDiagnostic to Sentry. The SDK supports this feature from iOS 15 and later and macOS 12
 * and later because, on these versions, @c MetricKit delivers diagnostic reports immediately, which
 * allows the Sentry SDK to apply the current data from the scope.
 * @note This feature is disabled by default.
 */
@property (nonatomic, assign) BOOL enableMetricKit API_AVAILABLE(
    ios(15.0), macos(12.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);

/**
 * When enabled, the SDK adds the raw MXDiagnosticPayloads as an attachment to the converted
 * SentryEvent. You need to enable @c enableMetricKit for this flag to work.
 *
 * @note Default value is @c NO.
 */
@property (nonatomic, assign) BOOL enableMetricKitRawPayload API_AVAILABLE(
    ios(15.0), macos(12.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);

#endif // SENTRY_HAS_METRIC_KIT

/**
 * @warning This is an experimental feature and may still have bugs.
 * @brief By enabling this, every UIViewController tracing transaction will wait
 * for a call to @c SentrySDK.reportFullyDisplayed().
 * @discussion Use this in conjunction with @c enableUIViewControllerTracing.
 * If @c SentrySDK.reportFullyDisplayed() is not called, the transaction will finish
 * automatically after 30 seconds and the `Time to full display` Span will be
 * finished with @c DeadlineExceeded status.
 * @note Default value is `NO`.
 */
@property (nonatomic) BOOL enableTimeToFullDisplayTracing;

/**
 * This feature is only available from Xcode 13 and from macOS 12.0, iOS 15.0, tvOS 15.0,
 * watchOS 8.0.
 *
 * @warning This is an experimental feature and may still have bugs.
 * @brief Stitches the call to Swift Async functions in one consecutive stack trace.
 * @note Default value is @c NO .
 */
@property (nonatomic, assign) BOOL swiftAsyncStacktraces;

/**
 * The path to store SDK data, like events, transactions, profiles, raw crash data, etc. We
 recommend only changing this when the default, e.g., in security environments, can't be accessed.
 *
 * @note The default is `NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask,
 YES)`.
 */
@property (nonatomic, copy) NSString *cacheDirectoryPath;

/**
 * Whether to enable Spotlight for local development. For more information see
 * https://spotlightjs.com/.
 *
 * @note Only set this option to @c YES while developing, not in production!
 */
@property (nonatomic, assign) BOOL enableSpotlight;

/**
 * The Spotlight URL. Defaults to http://localhost:8969/stream. For more information see
 * https://spotlightjs.com/
 */
@property (nonatomic, copy) NSString *spotlightUrl;

/**
 * Wether to enable DDM (delightful developer metrics) or not. For more information see
 * https://docs.sentry.io/product/metrics/.
 *
 * @warning This is an experimental feature and may still have bugs.
 * @note Default value is @c NO .
 */
@property (nonatomic, assign) BOOL enableMetrics;

/**
 * Wether to enable adding some default tags to every metrics or not. You need to enable @c
 * enableMetrics for this flag to work.
 *
 * @warning This is an experimental feature and may still have bugs.
 * @note Default value is @c YES .
 */
@property (nonatomic, assign) BOOL enableDefaultTagsForMetrics;

/**
 * Wether to enable connecting metrics to spans and transactions or not. You need to enable @c
 * enableMetrics for this flag to work.
 *
 * @warning This is an experimental feature and may still have bugs.
 * @note Default value is @c YES .
 */
@property (nonatomic, assign) BOOL enableSpanLocalMetricAggregation;

/**
 * This block can be used to modify the event before it will be serialized and sent.
 */
@property (nullable, nonatomic, copy) SentryBeforeEmitMetricCallback beforeEmitMetric;

/**
 * This aggregates options for experimental features.
 * Be aware that the options available for experimental can change at any time.
 */
@property (nonatomic, readonly) SentryExperimentalOptions *experimental;

@end

NS_ASSUME_NONNULL_END
