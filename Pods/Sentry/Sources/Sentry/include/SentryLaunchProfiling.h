#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentryHub;
@class SentryId;
@class SentryOptions;
@class SentryTracerConfiguration;
@class SentryTransactionContext;
@class SentryTracer;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyTracesSampleRate;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyTracesSampleRand;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRate;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyProfilesSampleRand;
#    if !SDK_V9
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyContinuousProfiling;
#    endif // !SDK_V9
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyContinuousProfilingV2;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle;
SENTRY_EXTERN NSString *const kSentryLaunchProfileConfigKeyWaitForFullDisplay;

/**
 * Whether or not the profiler started with the app launch. With trace profiling, this means there
 * is a tracer managing the profile that will eventually need to be stopped and either discarded (in
 * the case of auto performance transactions) or also transmitted. With continuous profiling, this
 * indicates whether or not the profiler that's currently running was started from app launch, or
 * later with a manual profiler start from the SDK consumer.
 */
SENTRY_EXTERN BOOL sentry_isTracingAppLaunch;

SENTRY_EXTERN SentryTracer *_Nullable sentry_launchTracer;

SENTRY_EXTERN void sentry_startLaunchProfile(void);

/**
 * Stop a launch tracer in order to stop the associated profiler. Must attach a hub, since there
 * isn't yet one when we start the launch tracer.
 * @noteIf the hub is nil, the tracer/profile will be discarded. This normally should always have a
 * valid hub, but tests may not have one and call this with nil instead.
 */
SENTRY_EXTERN void sentry_stopAndDiscardLaunchProfileTracer(SentryHub *_Nullable hub);

/**
 * Write a file to disk containing profile configuration options. The presence of this file will let
 * the profiler know to start on the app launch, and the sample rates contained will help thread
 * sampling decisions through to SentryHub later when it needs to start a transaction for the
 * profile to be attached to.
 */
SENTRY_EXTERN void sentry_configureLaunchProfilingForNextLaunch(SentryOptions *options);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
