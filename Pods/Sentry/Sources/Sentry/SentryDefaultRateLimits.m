#import "SentryDefaultRateLimits.h"
#import "SentryConcurrentRateLimitsDictionary.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDateUtil.h"
#import "SentryLog.h"
#import "SentryRateLimitParser.h"
#import "SentryRetryAfterHeaderParser.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDefaultRateLimits ()

@property (nonatomic, strong) SentryConcurrentRateLimitsDictionary *rateLimits;
@property (nonatomic, strong) SentryRetryAfterHeaderParser *retryAfterHeaderParser;
@property (nonatomic, strong) SentryRateLimitParser *rateLimitParser;
@property (nonatomic, strong) SentryCurrentDateProvider *currentDateProvider;
@property (nonatomic, strong) SentryDateUtil *dateUtil;

@end

@implementation SentryDefaultRateLimits

- (instancetype)initWithRetryAfterHeaderParser:
                    (SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                            andRateLimitParser:(SentryRateLimitParser *)rateLimitParser
                           currentDateProvider:(SentryCurrentDateProvider *)currentDateProvider
{
    if (self = [super init]) {
        self.rateLimits = [[SentryConcurrentRateLimitsDictionary alloc] init];
        self.retryAfterHeaderParser = retryAfterHeaderParser;
        self.rateLimitParser = rateLimitParser;
        self.currentDateProvider = currentDateProvider;
        self.dateUtil = [[SentryDateUtil alloc] initWithCurrentDateProvider:currentDateProvider];
    }
    return self;
}

- (BOOL)isRateLimitActive:(SentryDataCategory)category
{
    NSDate *categoryDate = [self.rateLimits getRateLimitForCategory:category];
    NSDate *allCategoriesDate = [self.rateLimits getRateLimitForCategory:kSentryDataCategoryAll];

    BOOL isActiveForCategory = [self.dateUtil isInFuture:categoryDate];
    BOOL isActiveForCategories = [self.dateUtil isInFuture:allCategoriesDate];

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
            SentryDataCategory category
                = sentryDataCategoryForNSUInteger(categoryAsNumber.unsignedIntegerValue);

            [self updateRateLimit:category withDate:limits[categoryAsNumber]];
        }
    } else if (response.statusCode == 429) {
        NSDate *retryAfterHeaderDate =
            [self.retryAfterHeaderParser parse:response.allHeaderFields[@"Retry-After"]];

        if (nil == retryAfterHeaderDate) {
            // parsing failed use default value
            retryAfterHeaderDate = [self.currentDateProvider.date dateByAddingTimeInterval:60];
        }

        [self updateRateLimit:kSentryDataCategoryAll withDate:retryAfterHeaderDate];
    }
}

- (void)updateRateLimit:(SentryDataCategory)category withDate:(NSDate *)newDate
{
    NSDate *existingDate = [self.rateLimits getRateLimitForCategory:category];
    NSDate *longerRateLimitDate = [SentryDateUtil getMaximumDate:existingDate andOther:newDate];
    [self.rateLimits addRateLimit:category validUntil:longerRateLimitDate];
}

@end

NS_ASSUME_NONNULL_END
