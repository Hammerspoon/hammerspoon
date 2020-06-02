#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(RateLimitCategoryMapper)
@interface SentryRateLimitCategoryMapper : NSObject

/** Maps an event type to the category for rate limiting.
 */
+ (NSString *)mapEventTypeToCategory:(NSString *)eventType;

+ (NSString *)mapEnvelopeItemTypeToCategory:(NSString *)itemType;

@end

NS_ASSUME_NONNULL_END

