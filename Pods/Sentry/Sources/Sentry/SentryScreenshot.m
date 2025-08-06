#import "SentryScreenshot.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryCompiler.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentrySwift.h"
#    import "SentryUIApplication.h"

@implementation SentryScreenshot {
    SentryViewPhotographer *photographer;
}

- (instancetype)init
{
    if (self = [super init]) {
        photographer = [[SentryViewPhotographer alloc]
                initWithRenderer:[[SentryDefaultViewRenderer alloc] init]
                   redactOptions:[[SentryRedactDefaultOptions alloc] init]
            enableMaskRendererV2:false];
    }
    return self;
}

- (NSArray<UIImage *> *)appScreenshotsFromMainThread
{
    __block NSArray<UIImage *> *result;

    void (^takeScreenShot)(void) = ^{ result = [self appScreenshots]; };

    [[SentryDependencyContainer sharedInstance].dispatchQueueWrapper
        dispatchSyncOnMainQueue:takeScreenShot];

    return result;
}

- (NSArray<NSData *> *)appScreenshotDatasFromMainThread
{
    __block NSArray<NSData *> *result;

    void (^takeScreenShot)(void) = ^{ result = [self appScreenshotsData]; };

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
    [[self appScreenshotsData]
        enumerateObjectsUsingBlock:^(NSData *obj, NSUInteger idx, BOOL *stop) {
            NSString *name = idx == 0
                ? @"screenshot.png"
                : [NSString stringWithFormat:@"screenshot-%li.png", (unsigned long)idx + 1];
            NSString *fileName = [imagesDirectoryPath stringByAppendingPathComponent:name];
            [obj writeToFile:fileName atomically:YES];
        }];
}

- (NSArray<UIImage *> *)appScreenshots
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];
    NSMutableArray<UIImage *> *result = [NSMutableArray<UIImage *> arrayWithCapacity:windows.count];

    for (UIWindow *window in windows) {
        CGSize size = window.frame.size;
        if (size.width == 0 || size.height == 0) {
            // avoid API errors reported as e.g.:
            // [Graphics] Invalid size provided to UIGraphicsBeginImageContext(): size={0, 0},
            // scale=1.000000
            continue;
        }

        UIImage *img = [photographer imageWithView:window];

        // this shouldn't happen now that we discard windows with either 0 height or 0 width,
        // but still, we shouldn't send any images with either one.
        if (LIKELY(img.size.width > 0 && img.size.height > 0)) {
            [result addObject:img];
        }
    }
    return result;
}

- (NSArray<NSData *> *)appScreenshotsData
{
    NSArray<UIImage *> *screenshots = [self appScreenshots];
    NSMutableArray<NSData *> *result =
        [NSMutableArray<NSData *> arrayWithCapacity:screenshots.count];

    for (UIImage *screenshot in screenshots) {
        // this shouldn't happen now that we discard windows with either 0 height or 0 width,
        // but still, we shouldn't send any images with either one.
        if (LIKELY(screenshot.size.width > 0 && screenshot.size.height > 0)) {
            NSData *bytes = UIImagePNGRepresentation(screenshot);
            if (bytes && bytes.length > 0) {
                [result addObject:bytes];
            }
        }
    }
    return result;
}

@end

#endif // SENTRY_HAS_UIKIT
