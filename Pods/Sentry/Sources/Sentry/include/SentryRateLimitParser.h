#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Parses the custom X-Sentry-Rate-Limits header.

 @discussion This header exists of a multiple quotaLimits seperated by ",".
 Each quotaLimit exists of retry_after:categories:scope.
 retry_after: seconds until the rate limit expires.
 categories: semicolon separated list of categories. If empty, this limit
 applies to all categories. scope: This can be ignored by SDKs.
 */
NS_SWIFT_NAME(RateLimitParser)
@interface SentryRateLimitParser : NSObject

- (NSDictionary<NSNumber *, NSDate *> *)parse:(NSString *)header;

@end

NS_ASSUME_NONNULL_END
