#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A 16 character Id.
 */

NS_SWIFT_NAME(SpanId)
@interface SentrySpanId : NSObject <NSCopying>

/**
 * Creates a SentrySpanId with a random 16 character Id.
 */
- (instancetype)init;

/**
 * Creates a SentrySpanId with the first 16 characters of the given UUID.
 */
- (instancetype)initWithUUID:(NSUUID *)uuid;

/**
 * Creates a SentrySpanId from a 16 character string.
 * Returns a empty SentrySpanId with the input is invalid.
 */
- (instancetype)initWithValue:(NSString *)value;

/**
 * Returns the Span Id Value
 */
@property (readonly, copy) NSString *sentrySpanIdString;

/**
 * A SentrySpanId with an empty Id "0000000000000000".
 */
@property (class, nonatomic, readonly, strong) SentrySpanId *empty;

@end

NS_ASSUME_NONNULL_END
