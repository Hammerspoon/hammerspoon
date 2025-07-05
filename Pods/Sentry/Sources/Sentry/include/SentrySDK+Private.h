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

#if TARGET_OS_OSX
/**
 * Captures an exception event and sends it to Sentry using the stacktrace from the exception.
 * @param exception The exception to send to Sentry.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureCrashOnException:(NSException *)exception
    NS_SWIFT_NAME(captureCrashOn(exception:));

#endif // TARGET_OS_OSX

#if SENTRY_HAS_UIKIT

/** Only needed for testing. We can't use `SENTRY_TEST || SENTRY_TEST_CI` because we call this from
 * the iOS-Swift sample app. */
+ (nullable NSArray<NSString *> *)relevantViewControllersNames;

#endif // SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END
