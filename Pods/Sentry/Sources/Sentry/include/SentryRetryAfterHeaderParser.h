#import <Foundation/Foundation.h>

@class SentryHttpDateParser;
@class SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

/** Parses value of HTTP header "Retry-After" which in most cases is sent in
 combination with HTTP status 429 Too Many Requests. For more details see:
 https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.37
*/
NS_SWIFT_NAME(RetryAfterHeaderParser)
@interface SentryRetryAfterHeaderParser : NSObject

- (instancetype)initWithHttpDateParser:(SentryHttpDateParser *)httpDateParser
                   currentDateProvider:(SentryCurrentDateProvider *)currentDateProvider;

/** Parses the HTTP header into a NSDate.

 @param retryAfterHeader The header value.

 @return NSDate representation of Retry-After. If the date can't be parsed nil
 is returned.
*/
- (NSDate *_Nullable)parse:(NSString *_Nullable)retryAfterHeader;

@end

NS_ASSUME_NONNULL_END
