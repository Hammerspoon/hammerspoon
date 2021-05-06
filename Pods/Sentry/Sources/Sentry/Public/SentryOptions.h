#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryDsn, SentrySdkInfo;

NS_SWIFT_NAME(Options)
@interface SentryOptions : NSObject

/**
 * Init SentryOptions.
 * @param options Options dictionary
 * @return SentryOptions
 */
- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error;

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
 * This property will be filled before the event is sent.
 */
@property (nullable, nonatomic, copy) NSString *dist;

/**
 * The environment used for this event
 */
@property (nullable, nonatomic, copy) NSString *environment;

/**
 * Specifies wether this SDK should send events to Sentry. If set to NO events will be
 * dropped in the client and not sent to Sentry. Default is YES.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * How many breadcrumbs do you want to keep in memory?
 * Default is 100.
 */
@property (nonatomic, assign) NSUInteger maxBreadcrumbs;

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
 * Indicates the percentage of events being sent to Sentry. Setting this to 0 or NIL discards all
 * events, 1.0 sends all events, 0.01 collects 1% of all events. The default is 1. The value needs
 * to be >= 0.0 and <= 1.0. When setting a value out of range  the SDK sets it to the default
 * of 1.0.
 */
@property (nullable, nonatomic, copy) NSNumber *sampleRate;

/**
 * Whether to enable automatic session tracking or not. Default is YES.
 */
@property (nonatomic, assign) BOOL enableAutoSessionTracking;

/**
 * Whether to enable to enable out of memory tracking or not. Default is YES.
 */
@property (nonatomic, assign) BOOL enableOutOfMemoryTracking;

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
 * Describes the Sentry SDK and its configuration used to capture and transmit an event.
 */
@property (nonatomic, readonly, strong) SentrySdkInfo *sdkInfo;

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
 * @discussion When the user of an event doesn't contain an IP address, the SDK sets it to
 * <code>{{auto}}</code> to instruct the server to use the connection IP address as the user
 * address.
 */
@property (nonatomic, assign) BOOL sendDefaultPii;

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

@end

NS_ASSUME_NONNULL_END
