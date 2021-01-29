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
@property (nonatomic, strong) NSString *_Nullable dsn;

/**
 * The parsed internal DSN.
 */
@property (nonatomic, strong) SentryDsn *_Nullable parsedDsn;

/**
 * debug [mode] sets a more verbose log level. Default is NO. If set to YES
 * sentry prints more log messages to the console.
 */
@property (nonatomic, assign) BOOL debug;

/**
 DEPRECATED: use debug bool instead (debug = YES maps to logLevel
 kSentryLogLevelError, debug = NO maps to loglevel kSentryLogLevelError). thus
 kSentryLogLevelNone and kSentryLogLevelDebug will be dropped entirely. defines
 the log level of sentry log (console output).
 */
@property (nonatomic, assign) SentryLogLevel logLevel;

/**
 * This property will be filled before the event is sent.
 */
@property (nonatomic, copy) NSString *_Nullable releaseName;

/**
 * This property will be filled before the event is sent.
 */
@property (nonatomic, copy) NSString *_Nullable dist;

/**
 * The environment used for this event
 */
@property (nonatomic, copy) NSString *_Nullable environment;

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
 * This block can be used to modify the event before it will be serialized and
 * sent
 */
@property (nonatomic, copy) SentryBeforeSendEventCallback _Nullable beforeSend;

/**
 * This block can be used to modify the event before it will be serialized and
 * sent
 */
@property (nonatomic, copy) SentryBeforeBreadcrumbCallback _Nullable beforeBreadcrumb;

/**
 * This gets called shortly after the initialization of the SDK when the last program execution
 * terminated with a crash. It is not guaranteed that this is called on the main thread.
 *
 * @discussion This callback is only executed once during the entire run of the program to avoid
 * multiple callbacks if there are multiple crash events to send. This can happen when the program
 * terminates with a crash before the SDK can send the crash event. You can look into beforeSend if
 * you prefer a callback for every event.
 */
@property (nonatomic, copy) SentryOnCrashedLastRunCallback _Nullable onCrashedLastRun;

/**
 * Array of integrations to install.
 */
@property (nonatomic, copy) NSArray<NSString *> *_Nullable integrations;

/**
 * Array of default integrations. Will be used if integrations are nil
 */
+ (NSArray<NSString *> *)defaultIntegrations;

/**
 * Defines the sample rate of SentryClient, should be a float between 0.0
 * and 1.0. valid settings are 0.0 - 1.0 and nil
 */
@property (nonatomic, copy) NSNumber *_Nullable sampleRate;

/**
 * Whether to enable automatic session tracking or not. Default is YES.
 */
@property (nonatomic, assign) BOOL enableAutoSessionTracking;

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

@end

NS_ASSUME_NONNULL_END
