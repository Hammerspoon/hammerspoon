#import "SentryRateLimits.h"
#import <Foundation/Foundation.h>

@protocol SentryEnvelopeRateLimitDelegate;

@class SentryEnvelope, SentryEnvelopeItem;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(EnvelopeRateLimit)
@interface SentryEnvelopeRateLimit : NSObject

- (instancetype)initWithRateLimits:(id<SentryRateLimits>)sentryRateLimits;

/**
 * Removes SentryEnvelopItems for which a rate limit is active.
 */
- (SentryEnvelope *)removeRateLimitedItems:(SentryEnvelope *)envelope;

- (void)setDelegate:(id<SentryEnvelopeRateLimitDelegate>)delegate;

@end

@protocol SentryEnvelopeRateLimitDelegate <NSObject>

- (void)envelopeItemDropped:(SentryEnvelopeItem *)envelopeItem
               withCategory:(SentryDataCategory)dataCategory;

@end

NS_ASSUME_NONNULL_END
