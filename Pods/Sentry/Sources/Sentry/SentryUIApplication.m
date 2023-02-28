#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT

@implementation SentryUIApplication

- (UIApplication *)sharedApplication
{
    if (![UIApplication respondsToSelector:@selector(sharedApplication)])
        return nil;

    return [UIApplication performSelector:@selector(sharedApplication)];
}

- (nullable id<UIApplicationDelegate>)getApplicationDelegate:(UIApplication *)application
{
    return application.delegate;
}

- (NSArray<UIScene *> *)getApplicationConnectedScenes:(UIApplication *)application
    API_AVAILABLE(ios(13.0), tvos(13.0))
{
    if (application && [application respondsToSelector:@selector(connectedScenes)]) {
        return [application.connectedScenes allObjects];
    }

    return @[];
}

- (NSArray<UIWindow *> *)windows
{
    UIApplication *app = [self sharedApplication];
    NSMutableArray *result = [NSMutableArray array];

    if (@available(iOS 13.0, tvOS 13.0, *)) {
        NSArray<UIScene *> *scenes = [self getApplicationConnectedScenes:app];
        for (UIScene *scene in scenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && scene.delegate &&
                [scene.delegate respondsToSelector:@selector(window)]) {
                id window = [scene.delegate performSelector:@selector(window)];
                if (window) {
                    [result addObject:window];
                }
            }
        }
    }

    id<UIApplicationDelegate> appDelegate = [self getApplicationDelegate:app];

    if ([appDelegate respondsToSelector:@selector(window)] && appDelegate.window != nil) {
        [result addObject:appDelegate.window];
    }

    return result;
}

@end

#endif
