#import "SentryProfilesSampler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryOptions+Private.h"
#    import "SentryTracesSampler.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryProfilesSamplerDecision

- (instancetype)initWithDecision:(SentrySampleDecision)decision
                   forSampleRate:(nullable NSNumber *)sampleRate
{
    if (self = [super init]) {
        _decision = decision;
        _sampleRate = sampleRate;
    }
    return self;
}

@end

@implementation SentryProfilesSampler {
    SentryOptions *_options;
}

- (instancetype)initWithOptions:(SentryOptions *)options random:(id<SentryRandom>)random
{
    if (self = [super init]) {
        _options = options;
        self.random = random;
    }
    return self;
}

- (instancetype)initWithOptions:(SentryOptions *)options
{
    return [self initWithOptions:options random:[SentryDependencyContainer sharedInstance].random];
}

- (SentryProfilesSamplerDecision *)sample:(SentrySamplingContext *)context
                    tracesSamplerDecision:(SentryTracesSamplerDecision *)tracesSamplerDecision
{
    // Profiles are always undersampled with respect to traces. If the trace is not sampled,
    // the profile will not be either. If the trace is sampled, we can proceed to checking
    // whether the associated profile should be sampled.
    if (tracesSamplerDecision.decision == kSentrySampleDecisionYes) {
        if (_options.profilesSampler != nil) {
            NSNumber *callbackDecision = _options.profilesSampler(context);
            if (callbackDecision != nil) {
                if (![_options isValidProfilesSampleRate:callbackDecision]) {
                    callbackDecision = _options.defaultProfilesSampleRate;
                }
            }
            if (callbackDecision != nil) {
                return [self calcSample:callbackDecision.doubleValue];
            }
        }

        if (_options.profilesSampleRate != nil) {
            return [self calcSample:_options.profilesSampleRate.doubleValue];
        }

        // Backward compatibility for clients that are still using the enableProfiling option.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (_options.enableProfiling) {
            return [[SentryProfilesSamplerDecision alloc] initWithDecision:kSentrySampleDecisionYes
                                                             forSampleRate:@1.0];
        }
#    pragma clang diagnostic pop
    }

    return [[SentryProfilesSamplerDecision alloc] initWithDecision:kSentrySampleDecisionNo
                                                     forSampleRate:nil];
}

- (SentryProfilesSamplerDecision *)calcSample:(double)rate
{
    double r = [self.random nextNumber];
    SentrySampleDecision decision = r <= rate ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
    return
        [[SentryProfilesSamplerDecision alloc] initWithDecision:decision
                                                  forSampleRate:[NSNumber numberWithDouble:rate]];
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
