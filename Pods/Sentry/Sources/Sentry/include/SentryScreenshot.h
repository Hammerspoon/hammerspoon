#import "SentryDefines.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryScreenshot : NSObject

/**
 * Get a screenshot of every open window in the app.
 * @return An array of @c NSData instances containing PNG images.
 */
- (NSArray<NSData *> *)appScreenshotDatasFromMainThread;

/**
 * Get a screenshot of every open window in the app.
 * @return An array of @c UIImage instances.
 */
- (NSArray<UIImage *> *)appScreenshotsFromMainThread;

/**
 * Save the current app screen shots in the given directory.
 * If an app has more than one screen, one image for each screen will be saved.
 *
 * @param imagesDirectoryPath The path where the images should be saved.
 */
- (void)saveScreenShots:(NSString *)imagesDirectoryPath;

- (NSArray<UIImage *> *)appScreenshots;
- (NSArray<NSData *> *)appScreenshotsData;
@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_REPLAY_SUPPORTED
