#import "SentryDefines.h"
#import "SentryTransport.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryDsn;

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
 * debug [mode] sets a more verbose log level. Default is @NO. If set to @YES
 * sentry prints more log messages to the console.
 */
@property (nonatomic, copy) NSNumber *debug;

/**
 DEPRECATED: use debug bool instead (debug = @YES maps to logLevel
 kSentryLogLevelError, debug = @NO maps to loglevel kSentryLogLevelError). thus
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
 * Is the client enabled?. Default is @YES, if set @NO sending of events will be
 * prevented.
 */
@property (nonatomic, copy) NSNumber *enabled;

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
 * Whether to enable automatic session tracking.
 */
@property (nonatomic, copy) NSNumber *enableAutoSessionTracking;

/**
 * The interval to end a session if the App goes to the background.
 */
@property (nonatomic, assign) NSUInteger sessionTrackingIntervalMillis;

/**
 * When enabled, stack traces are automatically attached to all messages logged. Stack traces are
 * always attached to exceptions but when this is set stack traces are also sent with messages.
 * Stack traces are only attached for the current thread.
 *
 * This feature is disabled by default.
 */
@property (nonatomic, copy) NSNumber *attachStacktrace;

@end

NS_ASSUME_NONNULL_END
