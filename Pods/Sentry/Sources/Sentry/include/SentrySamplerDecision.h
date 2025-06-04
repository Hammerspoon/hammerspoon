#import "SentrySampleDecision.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentrySamplerDecision : NSObject

@property (nonatomic, readonly) SentrySampleDecision decision;

@property (nonatomic, nullable, strong, readonly) NSNumber *sampleRand;

@property (nullable, nonatomic, strong, readonly) NSNumber *sampleRate;

- (instancetype)initWithDecision:(SentrySampleDecision)decision
                   forSampleRate:(nullable NSNumber *)sampleRate
                  withSampleRand:(nullable NSNumber *)sampleRand;

@end

NS_ASSUME_NONNULL_END
