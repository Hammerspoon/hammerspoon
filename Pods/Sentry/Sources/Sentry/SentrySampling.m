#import "SentrySampling.h"
#import "SentryDependencyContainer.h"
#import "SentryInternalDefines.h"
#import "SentryOptions.h"
#import "SentryRandom.h"
#import "SentrySampleDecision.h"
#import "SentrySamplerDecision.h"
#import "SentrySamplingContext.h"
#import "SentryTransactionContext.h"
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Private

/**
 * @return A sample rate if the specified sampler callback was defined on @c SentryOptions and
 * returned a valid value, @c nil otherwise.
 */
NSNumber *_Nullable _sentry_samplerCallbackRate(SentryTracesSamplerCallback _Nullable callback,
    SentrySamplingContext *context, NSNumber *_Nullable defaultSampleRate)
{
    if (callback == nil) {
        return nil;
    }

    NSNumber *callbackRate = callback(context);
    if (!sentry_isValidSampleRate(callbackRate)) {
        return defaultSampleRate;
    }

    return callbackRate;
}

SentrySamplerDecision *
_sentry_calcSample(NSNumber *rate)
{
    double random = [SentryDependencyContainer.sharedInstance.random nextNumber];
    SentrySampleDecision decision
        = random <= rate.doubleValue ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
    return [[SentrySamplerDecision alloc] initWithDecision:decision forSampleRate:rate];
}

SentrySamplerDecision *
_sentry_calcSampleFromNumericalRate(NSNumber *rate)
{
    if (rate == nil) {
        return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                 forSampleRate:nil];
    }

    return _sentry_calcSample(rate);
}

#pragma mark - Public

SentrySamplerDecision *
sentry_sampleTrace(SentrySamplingContext *context, SentryOptions *options)
{
    // check this transaction's sampling decision, if already decided
    if (context.transactionContext.sampled != kSentrySampleDecisionUndecided) {
        return
            [[SentrySamplerDecision alloc] initWithDecision:context.transactionContext.sampled
                                              forSampleRate:context.transactionContext.sampleRate];
    }

    NSNumber *callbackRate = _sentry_samplerCallbackRate(
        options.tracesSampler, context, SENTRY_DEFAULT_TRACES_SAMPLE_RATE);
    if (callbackRate != nil) {
        return _sentry_calcSample(callbackRate);
    }

    // check the _parent_ transaction's sampling decision, if any
    if (context.transactionContext.parentSampled != kSentrySampleDecisionUndecided) {
        return
            [[SentrySamplerDecision alloc] initWithDecision:context.transactionContext.parentSampled
                                              forSampleRate:context.transactionContext.sampleRate];
    }

    return _sentry_calcSampleFromNumericalRate(options.tracesSampleRate);
}

#if SENTRY_TARGET_PROFILING_SUPPORTED

SentrySamplerDecision *
sentry_sampleTraceProfile(SentrySamplingContext *context,
    SentrySamplerDecision *tracesSamplerDecision, SentryOptions *options)
{
    // Profiles are always undersampled with respect to traces. If the trace is not sampled,
    // the profile will not be either. If the trace is sampled, we can proceed to checking
    // whether the associated profile should be sampled.
    if (tracesSamplerDecision.decision != kSentrySampleDecisionYes) {
        return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                 forSampleRate:nil];
    }

    // Backward compatibility for clients that are still using the enableProfiling option.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (options.enableProfiling) {
        return [[SentrySamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                                 forSampleRate:@1.0];
    }
#    pragma clang diagnostic pop

    NSNumber *callbackRate = _sentry_samplerCallbackRate(
        options.profilesSampler, context, SENTRY_DEFAULT_PROFILES_SAMPLE_RATE);
    if (callbackRate != nil) {
        return _sentry_calcSample(callbackRate);
    }

    return _sentry_calcSampleFromNumericalRate(options.profilesSampleRate);
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_END
