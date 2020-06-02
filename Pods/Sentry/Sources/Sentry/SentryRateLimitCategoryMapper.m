#import <Foundation/Foundation.h>
#import "SentryRateLimitCategoryMapper.h"
#import "SentryRateLimitCategory.h"
#import "SentryEnvelopeItemType.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryRateLimitCategoryMapper ()

@end

@implementation SentryRateLimitCategoryMapper

+ (NSString *)mapEventTypeToCategory:(NSString *)eventType {
    // Currently we classify every event type as error.
    // This is going to change in the future.
    return SentryRateLimitCategoryError;
}

+ (NSString *)mapEnvelopeItemTypeToCategory:(NSString *)itemType {
    NSString *category = SentryRateLimitCategoryDefault;
    if ([itemType isEqualToString:SentryEnvelopeItemTypeEvent]) {
        category = SentryRateLimitCategoryError;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeSession]) {
        category = SentryRateLimitCategorySession;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeTransaction]) {
        category = SentryRateLimitCategoryTransaction;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeAttachment]) {
        category = SentryRateLimitCategoryAttachment;
    }
    return category;
}

@end

NS_ASSUME_NONNULL_END
