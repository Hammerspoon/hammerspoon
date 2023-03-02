#import "SentryDefaultRateLimits.h"
#import "SentryConcurrentRateLimitsDictionary.h"
#import "SentryCurrentDate.h"
#import "SentryDateUtil.h"
#import "SentryLog.h"
#import "SentryRateLimitCategoryMapper.h"
#import "SentryRateLimitParser.h"
#import "SentryRetryAfterHeaderParser.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDefaultRateLimits ()

@property (nonatomic, strong) SentryConcurrentRateLimitsDictionary *rateLimits;
@property (nonatomic, strong) SentryRetryAfterHeaderParser *retryAfterHeaderParser;
@property (nonatomic, strong) SentryRateLimitParser *rateLimitParser;

@end

@implementation SentryDefaultRateLimits

- (instancetype)initWithRetryAfterHeaderParser:
                    (SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                            andRateLimitParser:(SentryRateLimitParser *)rateLimitParser
{
    if (self = [super init]) {
        self.rateLimits = [[SentryConcurrentRateLimitsDictionary alloc] init];
        self.retryAfterHeaderParser = retryAfterHeaderParser;
        self.rateLimitParser = rateLimitParser;
    }
    return self;
}

- (BOOL)isRateLimitActive:(SentryRateLimitCategory)category
{
    NSDate *categoryDate = [self.rateLimits getRateLimitForCategory:category];
    NSDate *allCategoriesDate =
        [self.rateLimits getRateLimitForCategory:kSentryRateLimitCategoryAll];

    BOOL isActiveForCategory = [SentryDateUtil isInFuture:categoryDate];
    BOOL isActiveForCategories = [SentryDateUtil isInFuture:allCategoriesDate];

    if (isActiveForCategory || isActiveForCategories) {
        return YES;
    } else {
        return NO;
    }
}

- (void)update:(NSHTTPURLResponse *)response
{
    NSString *rateLimitsHeader = response.allHeaderFields[@"X-Sentry-Rate-Limits"];
    if (nil != rateLimitsHeader) {
        NSDictionary<NSNumber *, NSDate *> *limits = [self.rateLimitParser parse:rateLimitsHeader];

        for (NSNumber *categoryAsNumber in limits.allKeys) {
            SentryRateLimitCategory category = [SentryRateLimitCategoryMapper
                mapIntegerToCategory:(NSUInteger)[categoryAsNumber integerValue]];

            [self updateRateLimit:category withDate:limits[categoryAsNumber]];
        }
    } else if (response.statusCode == 429) {
        NSDate *retryAfterHeaderDate =
            [self.retryAfterHeaderParser parse:response.allHeaderFields[@"Retry-After"]];

        if (nil == retryAfterHeaderDate) {
            // parsing failed use default value
            retryAfterHeaderDate = [[SentryCurrentDate date] dateByAddingTimeInterval:60];
        }

        [self updateRateLimit:kSentryRateLimitCategoryAll withDate:retryAfterHeaderDate];
    }
}

- (void)updateRateLimit:(SentryRateLimitCategory)category withDate:(NSDate *)newDate
{
    NSDate *existingDate = [self.rateLimits getRateLimitForCategory:category];
    NSDate *longerRateLimitDate = [SentryDateUtil getMaximumDate:existingDate andOther:newDate];
    [self.rateLimits addRateLimit:category validUntil:longerRateLimitDate];
}

@end

NS_ASSUME_NONNULL_END
