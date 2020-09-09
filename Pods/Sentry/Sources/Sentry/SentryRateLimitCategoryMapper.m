#import "SentryRateLimitCategoryMapper.h"
#import "SentryEnvelopeItemType.h"
#import "SentryRateLimitCategory.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryRateLimitCategoryMapper ()

@end

@implementation SentryRateLimitCategoryMapper

+ (SentryRateLimitCategory)mapEventTypeToCategory:(NSString *)eventType
{
    // Currently we classify every event type as error.
    // This is going to change in the future.
    return kSentryRateLimitCategoryError;
}

+ (SentryRateLimitCategory)mapEnvelopeItemTypeToCategory:(NSString *)itemType
{
    SentryRateLimitCategory category = kSentryRateLimitCategoryDefault;
    if ([itemType isEqualToString:SentryEnvelopeItemTypeEvent]) {
        category = kSentryRateLimitCategoryError;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeSession]) {
        category = kSentryRateLimitCategorySession;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeTransaction]) {
        category = kSentryRateLimitCategoryTransaction;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeAttachment]) {
        category = kSentryRateLimitCategoryAttachment;
    }
    return category;
}

+ (SentryRateLimitCategory)mapIntegerToCategory:(NSUInteger)value
{
    SentryRateLimitCategory category = kSentryRateLimitCategoryUnknown;

    if (value == kSentryRateLimitCategoryAll) {
        category = kSentryRateLimitCategoryAll;
    }
    if (value == kSentryRateLimitCategoryDefault) {
        category = kSentryRateLimitCategoryDefault;
    }
    if (value == kSentryRateLimitCategoryError) {
        category = kSentryRateLimitCategoryError;
    }
    if (value == kSentryRateLimitCategorySession) {
        category = kSentryRateLimitCategorySession;
    }
    if (value == kSentryRateLimitCategoryTransaction) {
        category = kSentryRateLimitCategoryTransaction;
    }
    if (value == kSentryRateLimitCategoryAttachment) {
        category = kSentryRateLimitCategoryAttachment;
    }
    if (value == kSentryRateLimitCategoryUnknown) {
        category = kSentryRateLimitCategoryUnknown;
    }

    return category;
}

@end

NS_ASSUME_NONNULL_END
