#import "SentrySamplerDecision.h"

@implementation SentrySamplerDecision

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
