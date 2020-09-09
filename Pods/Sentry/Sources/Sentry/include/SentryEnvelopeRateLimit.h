#import "SentryRateLimits.h"
#import <Foundation/Foundation.h>

@class SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(EnvelopeRateLimit)
@interface SentryEnvelopeRateLimit : NSObject

- (instancetype)initWithRateLimits:(id<SentryRateLimits>)sentryRateLimits;

/**
 Removes SentryEnvelopItems for which a rate limit is active.
 */
- (SentryEnvelope *)removeRateLimitedItems:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
