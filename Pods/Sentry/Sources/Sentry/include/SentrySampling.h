#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;
@class SentrySamplerDecision;
@class SentrySamplingContext;

/**
 * Determines whether a trace should be sampled based on the context and options.
 */
SENTRY_EXTERN SentrySamplerDecision *sentry_sampleTrace(
    SentrySamplingContext *context, SentryOptions *options);

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Determines whether a profile should be sampled based on the context, options, and
 * whether the trace corresponding to the profile was sampled, to decide whether to configure the
 * next launch to start a trace profile.
 */
SENTRY_EXTERN SentrySamplerDecision *sentry_sampleTraceProfile(SentrySamplingContext *context,
    SentrySamplerDecision *tracesSamplerDecision, SentryOptions *options);

SENTRY_EXTERN SentrySamplerDecision *sentry_sampleProfileSession(float sessionSampleRate);
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_END
