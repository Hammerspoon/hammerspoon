#import <Foundation/Foundation.h>
#import "SentryDefaultRateLimits.h"
#import "SentryCurrentDate.h"
#import "SentryLog.h"
#import "SentryRateLimitParser.h"
#import "SentryRetryAfterHeaderParser.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const SentryDefaultRateLimitsAllCategories = @"";

@interface SentryDefaultRateLimits ()

/* Key is the type and value is valid until date */
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *rateLimits;

@property(nonatomic, strong) SentryRetryAfterHeaderParser *retryAfterHeaderParser;
@property(nonatomic, strong) SentryRateLimitParser *rateLimitParser;

@end

@implementation SentryDefaultRateLimits

- (instancetype) initWithRetryAfterHeaderParser:(SentryRetryAfterHeaderParser *)retryAfterHeaderParser
                 andRateLimitParser:(SentryRateLimitParser *)rateLimitParser{
    if (self = [super init]) {
        self.rateLimits = [[NSMutableDictionary alloc] init];
        self.retryAfterHeaderParser = retryAfterHeaderParser;
        self.rateLimitParser = rateLimitParser;
    }
    return self;
}

- (BOOL)isRateLimitActive:(NSString *)category {
    NSDate *categoryDate = self.rateLimits[category];
    NSDate *allCategoriesDate = self.rateLimits[SentryDefaultRateLimitsAllCategories];
    
    BOOL isActiveForCategory = [self isInFuture:categoryDate];
    BOOL isActiveForCategories = [self isInFuture:allCategoriesDate];
    
    if (isActiveForCategory) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Rate-Limit reached for type %@ until: %@", category, categoryDate] andLevel:kSentryLogLevelDebug];
        return YES;
    } else if (isActiveForCategories) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Rate-Limit reached for all types until: %@",  allCategoriesDate] andLevel:kSentryLogLevelDebug];
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)isInFuture:(NSDate *)date {
    NSComparisonResult result = [[SentryCurrentDate date] compare:date];
    return result == NSOrderedAscending;
}

- (void)update:(NSHTTPURLResponse *)response {
    NSString *rateLimitsHeader = response.allHeaderFields[@"X-Sentry-Rate-Limits"];
    if (nil != rateLimitsHeader) {
        NSDictionary<NSString *, NSDate *> * limits = [self.rateLimitParser parse:rateLimitsHeader];
        
        @synchronized (self) {
            [self.rateLimits addEntriesFromDictionary:limits];
        }
    } else if (response.statusCode == 429) {
        NSDate* retryAfterHeaderDate = [self.retryAfterHeaderParser parse:response.allHeaderFields[@"Retry-After"]];
        
        if (nil == retryAfterHeaderDate) {
            // parsing failed use default value
            retryAfterHeaderDate = [[SentryCurrentDate date] dateByAddingTimeInterval:60];
        }
        
        @synchronized (self) {
            self.rateLimits[SentryDefaultRateLimitsAllCategories] = retryAfterHeaderDate;
        }
    }
}

@end

NS_ASSUME_NONNULL_END
