#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSData *_Nullable sentry_gzippedWithCompressionLevel(
    NSData *data, NSInteger compressionLevel, NSError *_Nullable *_Nullable error);

/**
 * Adds a null character to the end of the byte array. This helps when strings should be null
 * terminated.
 */
NSData *_Nullable sentry_nullTerminated(NSData *_Nullable data);

/**
 * Calculates an CRC32 (Cyclic Redundancy Check 32) checksum for the string by first encoding it to
 * UTF8Encoded data.
 */
NSUInteger sentry_crc32ofString(NSString *value);

NS_ASSUME_NONNULL_END
