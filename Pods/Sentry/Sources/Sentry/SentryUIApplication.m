#import "SentryUIApplication.h"
#import "SentryLogC.h"
#import "SentryNSNotificationCenterWrapper.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@interface SentryUIApplication ()

@property (nonatomic, assign) UIApplicationState appState;
@property (nonatomic, strong) SentryNSNotificationCenterWrapper *notificationCenterWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

@implementation SentryUIApplication

- (instancetype)initWithNotificationCenterWrapper:
                    (SentryNSNotificationCenterWrapper *)notificationCenterWrapper
                             dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.notificationCenterWrapper = notificationCenterWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;

        [self.notificationCenterWrapper addObserver:self
                                           selector:@selector(didEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification];

        [self.notificationCenterWrapper addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:UIApplicationDidBecomeActiveNotification];

        // We store the application state when the app is initialized
        // and we keep track of its changes by the notifications
        // this way we avoid calling sharedApplication in a background thread
        [self.dispatchQueueWrapper
            dispatchAsyncOnMainQueue:^{ self.appState = self.sharedApplication.applicationState; }];
    }
    return self;
}

- (void)dealloc
{
    [self.notificationCenterWrapper removeObserver:self];
}

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
    __block NSArray<UIWindow *> *windows = nil;
    [_dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{
            UIApplication *app = [self sharedApplication];
            NSMutableSet *result = [NSMutableSet set];

            if (@available(iOS 13.0, tvOS 13.0, *)) {
                NSArray<UIScene *> *scenes = [self getApplicationConnectedScenes:app];
                for (UIScene *scene in scenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive
                        && scene.delegate &&
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

            windows = [result allObjects];
        }
                        timeout:0.01];
    return windows ?: @[];
}

- (NSArray<UIViewController *> *)relevantViewControllers
{
    NSArray<UIWindow *> *windows = [self windows];
    if ([windows count] == 0) {
        return nil;
    }

    NSMutableArray *result = [NSMutableArray array];

    for (UIWindow *window in windows) {
        NSArray<UIViewController *> *vcs = [self relevantViewControllerFromWindow:window];
        if (vcs != nil) {
            [result addObjectsFromArray:vcs];
        }
    }

    return result;
}

- (nullable NSArray<NSString *> *)relevantViewControllersNames
{
    __block NSArray<NSString *> *result = nil;
    __weak SentryUIApplication *weakSelf = self;

    [_dispatchQueueWrapper
        dispatchSyncOnMainQueue:^{
            if (weakSelf == nil) {
                SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not doing anything.");
                return;
            }

            NSArray<UIViewController *> *viewControllers = weakSelf.relevantViewControllers;
            NSMutableArray *vcsNames =
                [[NSMutableArray alloc] initWithCapacity:viewControllers.count];
            for (UIViewController *vc in viewControllers) {
                [vcsNames addObject:[SwiftDescriptor getViewControllerClassName:vc]];
            }
            result = [NSArray arrayWithArray:vcsNames];
        }
                        timeout:0.01];

    return result;
}

- (NSArray<UIViewController *> *)relevantViewControllerFromWindow:(UIWindow *)window
{
    UIViewController *rootViewController = window.rootViewController;
    if (rootViewController == nil) {
        return nil;
    }

    NSMutableArray<UIViewController *> *result =
        [NSMutableArray<UIViewController *> arrayWithObject:rootViewController];
    NSUInteger index = 0;

    while (index < result.count) {
        UIViewController *topVC = result[index];
        // If the view controller is presenting another one, usually in a modal form.
        if (topVC.presentedViewController != nil) {

            if ([topVC.presentationController isKindOfClass:UIAlertController.class]) {
                // If the view controller being presented is an Alert, we know that
                // we reached the end of the view controller stack and the presenter is
                // the top view controller.
                break;
            }

            [result replaceObjectAtIndex:index withObject:topVC.presentedViewController];

            continue;
        }

        // The top view controller is meant for navigation and not content
        if ([self isContainerViewController:topVC]) {
            NSArray<UIViewController *> *contentViewController =
                [self relevantViewControllerFromContainer:topVC];
            if (contentViewController != nil && contentViewController.count > 0) {
                [result removeObjectAtIndex:index];
                [result addObjectsFromArray:contentViewController];
            } else {
                break;
            }
            continue;
        }

        UIViewController *relevantChild = nil;
        for (UIViewController *childVC in topVC.childViewControllers) {
            // Sometimes a view controller is used as container for a navigation controller
            // If the navigation is occupying the whole view controller we will consider this the
            // case.
            if ([self isContainerViewController:childVC] && childVC.isViewLoaded
                && CGRectEqualToRect(childVC.view.frame, topVC.view.bounds)) {
                relevantChild = childVC;
                break;
            }
        }

        if (relevantChild != nil) {
            [result replaceObjectAtIndex:index withObject:relevantChild];
            continue;
        }

        index++;
    }

    return result;
}

- (BOOL)isContainerViewController:(UIViewController *)viewController
{
    return [viewController isKindOfClass:UINavigationController.class] ||
        [viewController isKindOfClass:UITabBarController.class] ||
        [viewController isKindOfClass:UISplitViewController.class] ||
        [viewController isKindOfClass:UIPageViewController.class];
}

- (nullable NSArray<UIViewController *> *)relevantViewControllerFromContainer:
    (UIViewController *)containerVC
{
    if ([containerVC isKindOfClass:UINavigationController.class]) {
        if ([(UINavigationController *)containerVC topViewController]) {
            return @[ [(UINavigationController *)containerVC topViewController] ];
        }
        return nil;
    }
    if ([containerVC isKindOfClass:UITabBarController.class]) {
        UITabBarController *tbController = (UITabBarController *)containerVC;
        NSInteger selectedIndex = tbController.selectedIndex;
        if (tbController.viewControllers.count > selectedIndex) {
            return @[ [tbController.viewControllers objectAtIndex:selectedIndex] ];
        } else {
            return nil;
        }
    }
    if ([containerVC isKindOfClass:UISplitViewController.class]) {
        UISplitViewController *splitVC = (UISplitViewController *)containerVC;
        if (splitVC.viewControllers.count > 0) {
            return [splitVC viewControllers];
        }
    }
    if ([containerVC isKindOfClass:UIPageViewController.class]) {
        UIPageViewController *pageVC = (UIPageViewController *)containerVC;
        if (pageVC.viewControllers.count > 0) {
            return @[ [[pageVC viewControllers] objectAtIndex:0] ];
        }
    }
    return nil;
}

- (UIApplicationState)applicationState
{
    return self.appState;
}

- (void)didEnterBackground
{
    self.appState = UIApplicationStateBackground;
}

- (void)didBecomeActive
{
    self.appState = UIApplicationStateActive;
}

- (BOOL)isActive
{
    return self.appState == UIApplicationStateActive;
}

@end

#endif // SENTRY_HAS_UIKIT
