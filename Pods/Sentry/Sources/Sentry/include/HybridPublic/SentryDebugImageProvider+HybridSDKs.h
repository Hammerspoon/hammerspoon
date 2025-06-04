#if __has_include(<Sentry/SentryDebugImageProvider.h>)
#    import <Sentry/SentryDebugImageProvider.h>
#else
#    import "SentryDebugImageProvider.h"
#endif

@class SentryDebugMeta;
@class SentryThread;
@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugImageProvider ()

/**
 * Returns a list of debug images that are being referenced by the given frames.
 * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
 * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForFrames:(NSArray<SentryFrame *> *)frames
    NS_SWIFT_NAME(getDebugImagesFromCacheForFrames(frames:));

/**
 * Returns a list of debug images that are being referenced in the given threads.
 * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
 * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForThreads:(NSArray<SentryThread *> *)threads
    NS_SWIFT_NAME(getDebugImagesFromCacheForThreads(threads:));

/**
 * Returns a list of debug images that are being referenced in the given image addresses.
 * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
 * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesForImageAddressesFromCache:
    (NSSet<NSString *> *)imageAddresses
    NS_SWIFT_NAME(getDebugImagesForImageAddressesFromCache(imageAddresses:));

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCache;

@end

NS_ASSUME_NONNULL_END
