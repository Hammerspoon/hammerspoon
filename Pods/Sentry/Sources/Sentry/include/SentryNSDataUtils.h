#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSData *_Nullable sentry_gzippedWithCompressionLevel(
    NSData *data, NSInteger compressionLevel, NSError *_Nullable *_Nullable error);

/**
 * Adds a null character to the end of the byte array. This helps when strings should be null
 * terminated.
 */
NSData *_Nullable sentry_nullTerminated(NSData *_Nullable data);

NS_ASSUME_NONNULL_END
