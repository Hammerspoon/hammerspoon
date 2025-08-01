#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySamplerDecision;
@class SentryProfileOptions;

/**
 * A data structure to hold in memory the options that were persisted when configuring launch
 * profiling on the previous launch's call to @c SentrySDK.startWith(options:) , and then is updated
 * from SDK start.
 * @note @c profilerSessionSampleDecision and @c profileOptions will be @c nil for continuous
 * profiling v1 (continuous profiling beta).
 */
@interface SentryProfileConfiguration : NSObject

SENTRY_NO_INIT

@property (assign, nonatomic, readonly) BOOL isContinuousV1;
@property (assign, nonatomic, readonly) BOOL waitForFullDisplay;
@property (assign, nonatomic, readonly) BOOL isProfilingThisLaunch;

/**
 * Continuous profiling will respect its own sampling rate, which is computed once for each Sentry
 * session. See calls to @c sentry_reevaluateSessionSampleRate() .
 */
@property (strong, nonatomic, nullable, readonly)
    SentrySamplerDecision *profilerSessionSampleDecision;

@property (strong, nonatomic, nullable, readonly) SentryProfileOptions *profileOptions;

- (void)reevaluateSessionSampleRate;

/** Initializer for SDK start if a configuration hasn't already been loaded for a launch profile. */
- (instancetype)initWithProfileOptions:(SentryProfileOptions *)options;

/**
 * Initializer for both trace-based and continuous V1 (aka continuous beta) launch profiles.
 */
- (instancetype)initWaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                             continuousV1:(BOOL)continuousV1;

/** Initializer for launch UI profiles (aka continuous V2). */
- (instancetype)initContinuousProfilingV2WaitingForFullDisplay:(BOOL)shouldWaitForFullDisplay
                                               samplerDecision:(SentrySamplerDecision *)decision
                                                profileOptions:(SentryProfileOptions *)options;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
