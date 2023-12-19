#import "SentryCrashDynamicLinker.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
  A wrapper around SentryCrash for testability.
 */
@protocol SentryCrashBinaryImageProvider <NSObject>

- (NSInteger)getImageCount;

/**
 * Returns information for the image at the specified index.
 * @param isCrash @c YES if we're collecting binary images for a crash report, @c NO if we're
 * gathering them for other backtrace information, like a performance transaction. If this is for a
 * crash, each image's data section crash info is also included.
 */
- (SentryCrashBinaryImage)getBinaryImage:(NSInteger)index isCrash:(BOOL)isCrash;

@end

NS_ASSUME_NONNULL_END
