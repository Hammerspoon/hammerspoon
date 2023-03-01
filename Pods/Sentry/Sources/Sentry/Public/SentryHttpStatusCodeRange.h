#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The Http status code range.
 * The range is inclusive so the min and max is considered part of the range.
 *
 * Example for a range: 400 to 499, 500 to 599, 400 to 599.
 * Example for a single status code 400, 500.
 */
NS_SWIFT_NAME(HttpStatusCodeRange)
@interface SentryHttpStatusCodeRange : NSObject
SENTRY_NO_INIT

@property (nonatomic, readonly) NSInteger min;

@property (nonatomic, readonly) NSInteger max;

/**
 * The Http status code min and max.
 * The range is inclusive so the min and max is considered part of the range.
 *
 * Example for a range: 400 to 499, 500 to 599, 400 to 599.
 */
- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max;

/**
 * The Http status code.
 *
 * Example for a single status code 400, 500.
 */
- (instancetype)initWithStatusCode:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
