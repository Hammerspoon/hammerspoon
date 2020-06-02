#import <Foundation/Foundation.h>

// more categories exist. New categories will be added and old SDKs are expected to fallback to `default`
static NSString * const SentryRateLimitCategoryDefault = @"default";
static NSString * const SentryRateLimitCategoryError = @"error";
static NSString * const SentryRateLimitCategorySession = @"session";
static NSString * const SentryRateLimitCategoryTransaction = @"transaction";
static NSString * const SentryRateLimitCategoryAttachment = @"attachment";
