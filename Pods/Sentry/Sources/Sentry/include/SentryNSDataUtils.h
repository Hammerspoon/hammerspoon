#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSDataUtils : NSObject

+ (NSData *_Nullable)sentry_gzippedWithData:(NSData *)data
                           compressionLevel:(NSInteger)compressionLevel
                                      error:(NSError *_Nullable *_Nullable)error;

@end

/**
 * Adds a null character to the end of the byte array. This helps when strings should be null
 * terminated.
 */
NSData *_Nullable sentry_nullTerminated(NSData *_Nullable data);

NS_ASSUME_NONNULL_END
