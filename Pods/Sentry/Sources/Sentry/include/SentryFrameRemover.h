#import <Foundation/Foundation.h>

@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryFrameRemover : NSObject

/**
 * Removes Sentry SDK frames until a frame from a different package is found.
 * @discussion When a user includes Sentry as a static library, the package is the same as the
 * application. Therefore removing frames with a package containing "sentry" doesn't work. We can't
 * look into the function name as in release builds, the function name can be obfuscated, or we
 * remove functions that are not from this SDK and contain "sentry". Therefore this logic only works
 * for apps including Sentry dynamically.
 */
+ (NSArray<SentryFrame *> *)removeNonSdkFrames:(NSArray<SentryFrame *> *)frames;

@end

NS_ASSUME_NONNULL_END
