#import "SentryEnvelopeRateLimit.h"
#import "SentryDataCategoryMapper.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryRateLimits.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryEnvelopeRateLimit ()

@property (nonatomic, strong) id<SentryRateLimits> rateLimits;
@property (nonatomic, weak) id<SentryEnvelopeRateLimitDelegate> delegate;

@end

@implementation SentryEnvelopeRateLimit

- (instancetype)initWithRateLimits:(id<SentryRateLimits>)sentryRateLimits
{
    if (self = [super init]) {
        self.rateLimits = sentryRateLimits;
    }
    return self;
}

- (void)setDelegate:(id<SentryEnvelopeRateLimitDelegate>)delegate
{
    _delegate = delegate;
}

- (SentryEnvelope *)removeRateLimitedItems:(SentryEnvelope *)envelope
{
    if (nil == envelope) {
        return envelope;
    }

    SentryEnvelope *result = envelope;

    NSArray<SentryEnvelopeItem *> *itemsToDrop = [self getEnvelopeItemsToDrop:envelope.items];

    if (itemsToDrop.count > 0) {
        NSArray<SentryEnvelopeItem *> *itemsToSend = [self getItemsToSend:envelope.items
                                                          withItemsToDrop:itemsToDrop];

        result = [[SentryEnvelope alloc] initWithHeader:envelope.header items:itemsToSend];
    }

    return result;
}

- (NSArray<SentryEnvelopeItem *> *)getEnvelopeItemsToDrop:(NSArray<SentryEnvelopeItem *> *)items
{
    NSMutableArray<SentryEnvelopeItem *> *itemsToDrop = [NSMutableArray new];

    for (SentryEnvelopeItem *item in items) {
        SentryDataCategory rateLimitCategory
            = sentryDataCategoryForEnvelopItemType(item.header.type);
        if ([self.rateLimits isRateLimitActive:rateLimitCategory]) {
            [itemsToDrop addObject:item];
            [self.delegate envelopeItemDropped:item withCategory:rateLimitCategory];
        }
    }

    return itemsToDrop;
}

- (NSArray<SentryEnvelopeItem *> *)getItemsToSend:(NSArray<SentryEnvelopeItem *> *)allItems
                                  withItemsToDrop:
                                      (NSArray<SentryEnvelopeItem *> *_Nonnull)itemsToDrop
{
    NSMutableArray<SentryEnvelopeItem *> *itemsToSend = [NSMutableArray new];

    for (SentryEnvelopeItem *item in allItems) {
        if (![itemsToDrop containsObject:item]) {
            [itemsToSend addObject:item];
        }
    }

    return itemsToSend;
}

@end

NS_ASSUME_NONNULL_END
