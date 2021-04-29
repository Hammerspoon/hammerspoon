#import "SentryTracesSampler.h"
#import "SentryOptions.h"
#import "SentrySamplingContext.h"
#import "SentryTransactionContext.h"
#import <SentryOptions+Private.h>

@implementation SentryTracesSampler {
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
    return [self initWithOptions:options random:[[SentryRandom alloc] init]];
}

- (SentrySampleDecision)sample:(SentrySamplingContext *)context
{
    if (context.transactionContext.sampled != kSentrySampleDecisionUndecided) {
        return context.transactionContext.sampled;
    }

    if (_options.tracesSampler != nil) {
        NSNumber *callbackDecision = _options.tracesSampler(context);
        if (callbackDecision != nil) {
            if (![_options isValidTracesSampleRate:callbackDecision]) {
                callbackDecision = _options.defaultTracesSampleRate;
            }
        }
        if (callbackDecision != nil) {
            return [self calcSample:callbackDecision.doubleValue];
        }
    }

    if (context.transactionContext.parentSampled != kSentrySampleDecisionUndecided)
        return context.transactionContext.parentSampled;

    if (_options.tracesSampleRate != nil)
        return [self calcSample:_options.tracesSampleRate.doubleValue];

    return kSentrySampleDecisionNo;
}

- (SentrySampleDecision)calcSample:(double)rate
{
    double r = [self.random nextNumber];
    return r <= rate ? kSentrySampleDecisionYes : kSentrySampleDecisionNo;
}

@end
