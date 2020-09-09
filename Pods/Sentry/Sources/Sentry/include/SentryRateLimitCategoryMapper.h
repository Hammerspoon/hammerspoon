#import "SentryRateLimitCategory.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(RateLimitCategoryMapper)
@interface SentryRateLimitCategoryMapper : NSObject

/** Maps an event type to the category for rate limiting.
 */
+ (SentryRateLimitCategory)mapEventTypeToCategory:(NSString *)eventType;

+ (SentryRateLimitCategory)mapEnvelopeItemTypeToCategory:(NSString *)itemType;

+ (SentryRateLimitCategory)mapIntegerToCategory:(NSUInteger)value;

@end

NS_ASSUME_NONNULL_END
