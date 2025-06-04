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

@class SentryAppStartMeasurement;
@class SentryEnvelope;
@class SentryFeedback;
@class SentryHub;
@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK ()

+ (void)captureFatalEvent:(SentryEvent *)event;

+ (void)captureFatalEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

#if SENTRY_HAS_UIKIT
+ (void)captureFatalAppHangEvent:(SentryEvent *)event;
#endif // SENTRY_HAS_UIKIT

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

@end

NS_ASSUME_NONNULL_END
