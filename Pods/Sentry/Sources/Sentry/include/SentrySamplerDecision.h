#import "SentrySampleDecision.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySamplerDecision : NSObject

@property (nonatomic, readonly) SentrySampleDecision decision;

@property (nullable, nonatomic, strong, readonly) NSNumber *sampleRate;

- (instancetype)initWithDecision:(SentrySampleDecision)decision
                   forSampleRate:(nullable NSNumber *)sampleRate;

@end

NS_ASSUME_NONNULL_END
