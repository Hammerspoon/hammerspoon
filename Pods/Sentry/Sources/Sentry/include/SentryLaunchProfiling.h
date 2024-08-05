#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentryHub;
@class SentryId;
@class SentryOptions;
@class SentryTracerConfiguration;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Whether or not the profiler started with the app launch. With trace profiling, this means there
 * is a tracer managing the profile that will eventually need to be stopped and either discarded (in
 * the case of auto performance transactions) or also transmitted. With continuous profiling, this
 * indicates whether or not the profiler that's currently running was started from app launch, or
 * later with a manual profiler start from the SDK consumer.
 */
SENTRY_EXTERN BOOL sentry_isTracingAppLaunch;

/** Try to start a profiled trace for this app launch, if the configuration allows. */
SENTRY_EXTERN void sentry_startLaunchProfile(void);

/**
 * Stop any profiled trace that may be in flight from the start of the app launch, and transmit the
 * dedicated transaction with the profiling data attached.
 */
SENTRY_EXTERN void sentry_stopAndTransmitLaunchProfile(SentryHub *hub);

/**
 * Stop the tracer that started the launch profiler. Use when the profiler will be attached to an
 * app start transaction and doesn't need to be attached to a dedicated tracer. The tracer managing
 * the profiler will be discarded in this case.
 */
void sentry_stopAndDiscardLaunchProfileTracer(void);

/**
 * Write a file to disk containing sample rates for profiles and traces. The presence of this file
 * will let the profiler know to start on the app launch, and the sample rates contained will help
 * thread sampling decisions through to SentryHub later when it needs to start a transaction for the
 * profile to be attached to.
 */
SENTRY_EXTERN void sentry_configureLaunchProfiling(SentryOptions *options);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
