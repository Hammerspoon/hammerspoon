#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SentryRateLimitCategory) {
    kSentryRateLimitCategoryAll,
    kSentryRateLimitCategoryDefault,
    kSentryRateLimitCategoryError,
    kSentryRateLimitCategorySession,
    kSentryRateLimitCategoryTransaction,
    kSentryRateLimitCategoryAttachment,
    kSentryRateLimitCategoryUnknown
};
