#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentryProfilingConditionals.h>
#else
#    import "SentryProfilingConditionals.h"
#endif

#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentrySDK.h>
#else
#    import "SentrySDK.h"
#endif

@class SentryHub, SentryId, SentryAppStartMeasurement, SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySDK ()

+ (void)captureCrashEvent:(SentryEvent *)event;

+ (void)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

/**
 * SDK private field to store the state if onCrashedLastRun was called.
 */
@property (nonatomic, class) BOOL crashedLastRunCalled;

+ (void)setDetectedStartUpCrash:(BOOL)value;

+ (void)setAppStartMeasurement:(nullable SentryAppStartMeasurement *)appStartMeasurement;

+ (nullable SentryAppStartMeasurement *)getAppStartMeasurement;

@property (nonatomic, class) NSUInteger startInvocations;
@property (nullable, nonatomic, class) NSDate *startTimestamp;

+ (SentryHub *)currentHub;

/**
 * The option used to start the SDK
 */
@property (nonatomic, nullable, readonly, class) SentryOptions *options;

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

/**
 * Needed by hybrid SDKs as react-native to synchronously capture an envelope.
 */
+ (void)captureEnvelope:(SentryEnvelope *)envelope;

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Start a new continuous profiling session if one is not already running.
 * @seealso https://docs.sentry.io/platforms/apple/profiling/
 */
+ (void)startProfiler;

/**
 * Stop a continuous profiling session if there is one ongoing.
 * @seealso https://docs.sentry.io/platforms/apple/profiling/
 */
+ (void)stopProfiler;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

NS_ASSUME_NONNULL_END
