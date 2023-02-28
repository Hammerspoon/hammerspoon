#import "SentryDataCategory.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A thread safe wrapper around a dictionary to store rate limits.
 */
@interface SentryConcurrentRateLimitsDictionary : NSObject

/**
 Adds the passed rate limit for the given category. If a rate limit already
 exists it is overwritten.
 */
- (void)addRateLimit:(SentryDataCategory)category validUntil:(NSDate *)date;

/** Returns the date until the rate limit is active. */
- (NSDate *)getRateLimitForCategory:(SentryDataCategory)category;

@end

NS_ASSUME_NONNULL_END
