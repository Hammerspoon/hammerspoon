#import "SentrySamplerDecision.h"

@implementation SentrySamplerDecision

- (instancetype)initWithDecision:(SentrySampleDecision)decision
                   forSampleRate:(nullable NSNumber *)sampleRate
                  withSampleRand:(nullable NSNumber *)sampleRand
{
    if (self = [super init]) {
        _decision = decision;
        _sampleRate = sampleRate;
        _sampleRand = sampleRand;
    }
    return self;
}

@end
