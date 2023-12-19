#import <Foundation/Foundation.h>

@class SentryDebugMeta, SentryThread, SentryFrame;

NS_ASSUME_NONNULL_BEGIN

/**
 * Reserved for hybrid SDKs that the debug image list for symbolication.
 * @todo This class should be renamed to @c SentryDebugImage in a future version.
 */
@interface SentryDebugImageProvider : NSObject

- (instancetype)init;

/**
 * Returns a list of debug images that are being referenced in the given threads.
 * @param threads A list of @c SentryThread that may or may not contain stacktraces.
 * @warning This assumes a crash has occurred and attempts to read the crash information from each
 * image's data segment, which may not be present or be invalid if a crash has not actually
 * occurred. To avoid this, use the new @c -[getDebugImagesForThreads:isCrash:] instead.
 * @deprecated Use @c -[getDebugImagesForThreads:isCrash:] instead.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesForThreads:(NSArray<SentryThread *> *)threads
    DEPRECATED_MSG_ATTRIBUTE("Use -[getDebugImagesForThreads:isCrash:] instead.");

/**
 * Returns a list of debug images that are being referenced in the given threads.
 * @param threads A list of @c SentryThread that may or may not contain stacktraces.
 * @param isCrash @c YES if we're collecting binary images for a crash report, @c NO if we're
 * gathering them for other backtrace information, like a performance transaction. If this is for a
 * crash, each image's data section crash info is also included.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesForThreads:(NSArray<SentryThread *> *)threads
                                                 isCrash:(BOOL)isCrash;

/**
 * Returns a list of debug images that are being referenced by the given frames.
 * @param frames A list of stack frames.
 * @warning This assumes a crash has occurred and attempts to read the crash information from each
 * image's data segment, which may not be present or be invalid if a crash has not actually
 * occurred. To avoid this, use the new @c -[getDebugImagesForFrames:isCrash:] instead.
 * @deprecated Use @c -[getDebugImagesForFrames:isCrash:] instead.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesForFrames:(NSArray<SentryFrame *> *)frames
    DEPRECATED_MSG_ATTRIBUTE("Use -[getDebugImagesForFrames:isCrash:] instead.");

/**
 * Returns a list of debug images that are being referenced by the given frames.
 * @param frames A list of stack frames.
 * @param isCrash @c YES if we're collecting binary images for a crash report, @c NO if we're
 * gathering them for other backtrace information, like a performance transaction. If this is for a
 * crash, each image's data section crash info is also included.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesForFrames:(NSArray<SentryFrame *> *)frames
                                                isCrash:(BOOL)isCrash;

/**
 * Returns the current list of debug images. Be aware that the @c SentryDebugMeta is actually
 * describing a debug image.
 * @warning This assumes a crash has occurred and attempts to read the crash information from each
 * image's data segment, which may not be present or be invalid if a crash has not actually
 * occurred. To avoid this, use the new @c -[getDebugImagesCrashed:] instead.
 * @deprecated Use @c -[getDebugImagesCrashed:] instead.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImages DEPRECATED_MSG_ATTRIBUTE(
    "Use -[getDebugImagesCrashed:] instead.");

/**
 * Returns the current list of debug images. Be aware that the @c SentryDebugMeta is actually
 * describing a debug image.
 * @param isCrash @c YES if we're collecting binary images for a crash report, @c NO if we're
 * gathering them for other backtrace information, like a performance transaction. If this is for a
 * crash, each image's data section crash info is also included.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesCrashed:(BOOL)isCrash;

@end

NS_ASSUME_NONNULL_END
