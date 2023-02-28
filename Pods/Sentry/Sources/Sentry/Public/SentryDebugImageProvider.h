#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryDebugMeta, SentryThread, SentryFrame;

NS_ASSUME_NONNULL_BEGIN

/**
 * Reserved for hybrid SDKs that the debug image list for symbolication.
 */
@interface SentryDebugImageProvider : NSObject

- (instancetype)init;

/**
 * Returns a list of debug images that are being referenced in the given threads.
 *
 * @param threads A list of SentryThread that may or may not contains a stacktrace.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesForThreads:(NSArray<SentryThread *> *)threads;

/**
 * Returns a list of debug images that are being referenced by the given frames.
 *
 * @param frames A list of stack frames.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesForFrames:(NSArray<SentryFrame *> *)frames;

/**
 * Returns the current list of debug images. Be aware that the SentryDebugMeta is actually
 * describing a debug image. This class should be renamed to SentryDebugImage in a future version.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImages;

@end

NS_ASSUME_NONNULL_END
