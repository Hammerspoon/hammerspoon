#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

/**
 * Reserved for hybrid SDKs that the debug image list for symbolication.
 */
@interface SentryDebugImageProvider : NSObject

- (instancetype)init;

/**
 * Returns the current list of debug images. Be aware that the SentryDebugMeta is actually
 * describing a debug image. This class should be renamed to SentryDebugImage in a future version.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImages;

@end

NS_ASSUME_NONNULL_END
