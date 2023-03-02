#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
NSData (Sentry)

/**
 * Adds a null character to the end of the byte array. This helps when strings should be null
 * terminated.
 */
- (nullable NSData *)sentry_nullTerminated;

@end

NS_ASSUME_NONNULL_END
