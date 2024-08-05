#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryViewHierarchy : NSObject

/**
 Get the view hierarchy in a json format.
 Always runs in the main thread.
 */
- (nullable NSData *)appViewHierarchyFromMainThread;

/**
 Get the view hierarchy in a json format.
 */
- (nullable NSData *)appViewHierarchy;

/**
 * Save the current app view hierarchy in the given file path.
 *
 * @param filePath The full path where the view hierarchy should be saved.
 */
- (BOOL)saveViewHierarchy:(NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
#endif
