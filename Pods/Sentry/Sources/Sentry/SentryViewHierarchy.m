#import "SentryViewHierarchy.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCrashFileUtils.h"
#    import "SentryCrashJSONCodec.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryLog.h"
#    import "SentrySwift.h"
#    import "SentryUIApplication.h"
#    import <UIKit/UIKit.h>

static int
writeJSONDataToFile(const char *const data, const int length, void *const userData)
{
    const int fd = *((int *)userData);
    const bool success = sentrycrashfu_writeBytesToFD(fd, data, length);
    return success ? SentryCrashJSON_OK : SentryCrashJSON_ERROR_CANNOT_ADD_DATA;
}

static int
writeJSONDataToMemory(const char *const data, const int length, void *const userData)
{
    NSMutableData *memory = ((__bridge NSMutableData *)userData);
    [memory appendBytes:data length:length];
    return SentryCrashJSON_OK;
}

@implementation SentryViewHierarchy

- (BOOL)saveViewHierarchy:(NSString *)filePath
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    const char *path = [filePath UTF8String];
    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        SENTRY_LOG_DEBUG(@"Could not open file %s for writing: %s", path, strerror(errno));
        return NO;
    }

    BOOL result = [self processViewHierarchy:windows addFunction:writeJSONDataToFile userData:&fd];

    close(fd);
    return result;
}

- (NSData *)appViewHierarchyFromMainThread
{
    __block NSData *result;

    void (^fetchViewHierarchy)(void) = ^{ result = [self appViewHierarchy]; };

    [[SentryDependencyContainer sharedInstance].dispatchQueueWrapper
        dispatchSyncOnMainQueue:fetchViewHierarchy];

    return result;
}

- (NSData *)appViewHierarchy
{
    NSMutableData *result = [[NSMutableData alloc] init];
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    if (![self processViewHierarchy:windows
                        addFunction:writeJSONDataToMemory
                           userData:(__bridge void *)(result)]) {

        result = nil;
    }

    return result;
}

#    define tryJson(code)                                                                          \
        if ((result = (code)) != SentryCrashJSON_OK)                                               \
            return result;

- (BOOL)processViewHierarchy:(NSArray<UIView *> *)windows
                 addFunction:(SentryCrashJSONAddDataFunc)addJSONDataFunc
                    userData:(void *const)userData
{

    __block SentryCrashJSONEncodeContext JSONContext;
    sentrycrashjson_beginEncode(&JSONContext, NO, addJSONDataFunc, userData);

    int (^serializeJson)(void) = ^int() {
        int result;
        tryJson(sentrycrashjson_beginObject(&JSONContext, NULL));
        tryJson(sentrycrashjson_addStringElement(
            &JSONContext, "rendering_system", "UIKIT", SentryCrashJSON_SIZE_AUTOMATIC));
        tryJson(sentrycrashjson_beginArray(&JSONContext, "windows"));

        for (UIView *window in windows) {
            tryJson([self viewHierarchyFromView:window intoContext:&JSONContext]);
        }

        tryJson(sentrycrashjson_endContainer(&JSONContext));

        result = sentrycrashjson_endEncode(&JSONContext);
        return result;
    };

    int result = serializeJson();
    if (result != SentryCrashJSON_OK) {
        SENTRY_LOG_DEBUG(
            @"Could not create view hierarchy json: %s", sentrycrashjson_stringForError(result));
        return NO;
    }
    return YES;
}

- (int)viewHierarchyFromView:(UIView *)view intoContext:(SentryCrashJSONEncodeContext *)context
{
    int result = 0;
    tryJson(sentrycrashjson_beginObject(context, NULL));
    const char *viewClassName = [[SwiftDescriptor getObjectClassName:view] UTF8String];
    tryJson(sentrycrashjson_addStringElement(
        context, "type", viewClassName, SentryCrashJSON_SIZE_AUTOMATIC));

    if (view.accessibilityIdentifier && view.accessibilityIdentifier.length != 0) {
        tryJson(sentrycrashjson_addStringElement(context, "identifier",
            view.accessibilityIdentifier.UTF8String, SentryCrashJSON_SIZE_AUTOMATIC));
    }

    tryJson(sentrycrashjson_addFloatingPointElement(context, "width", view.frame.size.width));
    tryJson(sentrycrashjson_addFloatingPointElement(context, "height", view.frame.size.height));
    tryJson(sentrycrashjson_addFloatingPointElement(context, "x", view.frame.origin.x));
    tryJson(sentrycrashjson_addFloatingPointElement(context, "y", view.frame.origin.y));
    tryJson(sentrycrashjson_addFloatingPointElement(context, "alpha", view.alpha));
    tryJson(sentrycrashjson_addBooleanElement(context, "visible", !view.hidden));

    if ([view.nextResponder isKindOfClass:[UIViewController class]]) {
        UIViewController *vc = (UIViewController *)view.nextResponder;
        if (vc.view == view) {
            const char *viewControllerClassName =
                [[SwiftDescriptor getObjectClassName:vc] UTF8String];
            tryJson(sentrycrashjson_addStringElement(context, "view_controller",
                viewControllerClassName, SentryCrashJSON_SIZE_AUTOMATIC));
        }
    }

    tryJson(sentrycrashjson_beginArray(context, "children"));
    for (UIView *child in view.subviews) {
        tryJson([self viewHierarchyFromView:child intoContext:context]);
    }
    tryJson(sentrycrashjson_endContainer(context));
    tryJson(sentrycrashjson_endContainer(context));
    return result;
}

@end

#endif // SENTRY_HAS_UIKIT
