#import <Foundation/Foundation.h>

@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryFrameRemover : NSObject

/**
 * Removes Sentry SDK frames until a frame from a different package is found.
 */
- (NSArray<SentryFrame *> *)removeNonSdkFrames:(NSArray<SentryFrame *> *)frames;

@end

NS_ASSUME_NONNULL_END
