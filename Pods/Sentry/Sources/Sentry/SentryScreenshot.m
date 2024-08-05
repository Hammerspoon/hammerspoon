#import "SentryScreenshot.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCompiler.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryUIApplication.h"
#    import <UIKit/UIKit.h>

@implementation SentryScreenshot

- (NSArray<NSData *> *)appScreenshotsFromMainThread
{
    __block NSArray *result;

    void (^takeScreenShot)(void) = ^{ result = [self appScreenshots]; };

    [[SentryDependencyContainer sharedInstance].dispatchQueueWrapper
        dispatchSyncOnMainQueue:takeScreenShot];

    return result;
}

- (void)saveScreenShots:(NSString *)imagesDirectoryPath
{
    // This function does not dispatch the screenshot to the main thread.
    // The caller should be aware of that.
    // We did it this way because we use this function to save screenshots
    // during signal handling, and if we dispatch it to the main thread,
    // that is probably blocked by the crash event, we freeze the application.
    [[self appScreenshots] enumerateObjectsUsingBlock:^(NSData *obj, NSUInteger idx, BOOL *stop) {
        NSString *name = idx == 0
            ? @"screenshot.png"
            : [NSString stringWithFormat:@"screenshot-%li.png", (unsigned long)idx + 1];
        NSString *fileName = [imagesDirectoryPath stringByAppendingPathComponent:name];
        [obj writeToFile:fileName atomically:YES];
    }];
}

- (NSArray<NSData *> *)appScreenshots
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:windows.count];

    for (UIWindow *window in windows) {
        CGSize size = window.frame.size;
        if (size.width == 0 || size.height == 0) {
            // avoid API errors reported as e.g.:
            // [Graphics] Invalid size provided to UIGraphicsBeginImageContext(): size={0, 0},
            // scale=1.000000
            continue;
        }

        UIGraphicsBeginImageContext(size);

        if ([window drawViewHierarchyInRect:window.bounds afterScreenUpdates:false]) {
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            // this shouldn't happen now that we discard windows with either 0 height or 0 width,
            // but still, we shouldn't send any images with either one.
            if (LIKELY(img.size.width > 0 && img.size.height > 0)) {
                NSData *bytes = UIImagePNGRepresentation(img);
                if (bytes && bytes.length > 0) {
                    [result addObject:bytes];
                }
            }
        }

        UIGraphicsEndImageContext();
    }
    return result;
}

@end

#endif // SENTRY_HAS_UIKIT
