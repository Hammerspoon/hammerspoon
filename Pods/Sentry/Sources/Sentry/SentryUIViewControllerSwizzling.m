#import "SentryUIViewControllerSwizzling.h"
#import "SentryDefaultObjCRuntimeWrapper.h"
#import "SentryLog.h"
#import "SentryProcessInfoWrapper.h"
#import "SentrySubClassFinder.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerPerformanceTracker.h"
#import <SentryDispatchQueueWrapper.h>
#import <SentryInAppLogic.h>
#import <SentryOptions.h>
#import <UIViewController+Sentry.h>
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

/**
 * 'swizzleRootViewControllerFromUIApplication:' requires an object that conforms to
 * 'SentryUIApplication' to swizzle it, this way, instead of relying on UIApplication, we can test
 * with a mock class.
 *
 * This category makes UIApplication conform to
 * SentryUIApplication in order to be used by 'SentryUIViewControllerSwizzling'.
 */
@interface
UIApplication (SentryUIApplication) <SentryUIApplication>
@end

@interface
SentryUIViewControllerSwizzling ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) id<SentryObjCRuntimeWrapper> objcRuntimeWrapper;
@property (nonatomic, strong) SentrySubClassFinder *subClassFinder;
@property (nonatomic, strong) NSMutableSet<NSString *> *imagesActedOnSubclassesOfUIViewControllers;
@property (nonatomic, strong) SentryProcessInfoWrapper *processInfoWrapper;

@end

@implementation SentryUIViewControllerSwizzling

- (instancetype)initWithOptions:(SentryOptions *)options
                  dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
             objcRuntimeWrapper:(id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
                 subClassFinder:(SentrySubClassFinder *)subClassFinder
             processInfoWrapper:(SentryProcessInfoWrapper *)processInfoWrapper
{
    if (self = [super init]) {
        self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                            inAppExcludes:options.inAppExcludes];
        self.dispatchQueue = dispatchQueue;
        self.objcRuntimeWrapper = objcRuntimeWrapper;
        self.subClassFinder = subClassFinder;
        self.imagesActedOnSubclassesOfUIViewControllers = [NSMutableSet new];
        self.processInfoWrapper = processInfoWrapper;
    }

    return self;
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

- (void)start
{
    id<SentryUIApplication> app = [self findApp];
    if (app != nil) {

        // If an app targets, for example, iOS 13 or lower, the UIKit inits the initial/root view
        // controller before the SentrySDK is initialized. Therefore, we manually call swizzle here
        // not to lose auto-generated transactions for the initial view controller. As we use
        // SentrySwizzleModeOncePerClassAndSuperclasses, we don't have to worry about swizzling
        // twice. We could also use objc_getClassList to lookup sub classes of UIViewController, but
        // the lookup can take around 60ms, which is not acceptable.
        if (![self swizzleRootViewControllerFromUIApplication:app]) {
            SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: Failed to find root UIViewController "
                             @"from UIApplicationDelegate. Trying to use "
                             @"UISceneWillConnectNotification notification.");

            if (@available(iOS 13.0, tvOS 13.0, *)) {
                [NSNotificationCenter.defaultCenter
                    addObserver:self
                       selector:@selector(swizzleRootViewControllerFromSceneDelegateNotification:)
                           name:UISceneWillConnectNotification
                         object:nil];
            } else {
                SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: iOS version older then 13. There is "
                                 @"no UISceneWillConnectNotification notification. Could not find "
                                 @"a rootViewController");
            }
        }

        [self swizzleAllSubViewControllersInApp:app];
    } else {
        // If we can't find an UIApplication instance we may use the current process path as the
        // image name. This mostly happens with SwiftUI projects.
        NSString *processImage = self.processInfoWrapper.processPath;
        if (processImage) {
            [self swizzleUIViewControllersOfImage:processImage];
        } else {
            SENTRY_LOG_DEBUG(
                @"UIViewControllerSwizziling: Did not found image name from current process. "
                @"Skipping Swizzling of view controllers");
        }
    }

    [self swizzleUIViewController];
}

- (id<SentryUIApplication>)findApp
{
    if (![UIApplication respondsToSelector:@selector(sharedApplication)]) {
        SENTRY_LOG_DEBUG(
            @"UIViewControllerSwizziling: UIApplication doesn't respond to sharedApplication.");
        return nil;
    }

    UIApplication *app = [UIApplication performSelector:@selector(sharedApplication)];

    if (app == nil) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: UIApplication.sharedApplication is nil.");
        return nil;
    }

    return app;
}

- (void)swizzleAllSubViewControllersInApp:(id<SentryUIApplication>)app
{
    if (app.delegate == nil) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizzling: App delegate is nil. Skipping swizzling "
                         @"UIViewControllers in the app image.");
        return;
    }

    [self swizzleUIViewControllersOfClassesInImageOf:[app.delegate class]];
}

- (void)swizzleUIViewControllersOfClassesInImageOf:(Class)class
{
    if (class == NULL) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizzling: class is NULL. Skipping swizzling of classes "
                         @"in same image.");
        return;
    }

    SENTRY_LOG_DEBUG(@"UIViewControllerSwizzling: Class to get the image name: %@", class);

    const char *imageNameAsCharArray = [self.objcRuntimeWrapper class_getImageName:class];

    if (imageNameAsCharArray == NULL) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: Wasn't able to get image name of the class: "
                         @"%@. Skipping swizzling of classes in same image.",
            class);
        return;
    }

    NSString *imageName = [NSString stringWithCString:imageNameAsCharArray
                                             encoding:NSUTF8StringEncoding];

    if (imageName == nil || imageName.length == 0) {
        SENTRY_LOG_DEBUG(
            @"UIViewControllerSwizziling: Wasn't able to get the app image name of the app "
            @"delegate class: %@. Skipping swizzling of classes in same image.",
            class);
        return;
    }

    [self swizzleUIViewControllersOfImage:imageName];
}

- (void)swizzleUIViewControllersOfImage:(NSString *)imageName
{
    if ([imageName containsString:@"UIKitCore"]) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: Skipping UIKitCore.");
        return;
    }

    if ([self.imagesActedOnSubclassesOfUIViewControllers containsObject:imageName]) {
        SENTRY_LOG_DEBUG(
            @"UIViewControllerSwizziling: Already swizzled UIViewControllers in image: %@.",
            imageName);
        return;
    }

    [self.imagesActedOnSubclassesOfUIViewControllers addObject:imageName];

    // Swizzle all custom UIViewControllers. Cause loading all classes can take a few milliseconds,
    // the SubClassFinder does this on a background thread, which should be fine because the SDK
    // swizzles the root view controller and its children above. After finding all subclasses of the
    // UIViewController, we swizzles them on the main thread. Swizzling the UIViewControllers on a
    // background thread led to crashes, see GH-1366.

    // Previously, the code intercepted the ViewController initializers with swizzling to swizzle
    // the lifecycle methods. This approach led to UIViewControllers crashing when using a
    // convenience initializer, see GH-1355. The error occurred because our swizzling logic adds the
    // method to swizzle if the class doesn't implement it. It seems like adding an extra
    // initializer causes problems with the rules for initialization in Swift, see
    // https://docs.swift.org/swift-book/LanguageGuide/Initialization.html#ID216.
    [self.subClassFinder
        actOnSubclassesOfViewControllerInImage:imageName
                                         block:^(Class class) {
                                             [self swizzleViewControllerSubClass:class];
                                         }];
}

/**
 * If the iOS version is 13 or newer, and the project does not use a custom Window initialization
 * the app uses a UIScenes to manage windows instead of the old AppDelegate.
 * We wait for the first scene to connect to the app in order to find the rootViewController.
 */
- (void)swizzleRootViewControllerFromSceneDelegateNotification:(NSNotification *)notification
{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        if (![notification.name isEqualToString:UISceneWillConnectNotification])
            return;

        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:UISceneWillConnectNotification
                                                    object:nil];

        // The object of a UISceneWillConnectNotification should be a NSWindowScene
        if (![notification.object respondsToSelector:@selector(windows)]) {
            SENTRY_LOG_DEBUG(
                @"UIViewControllerSwizziling: Failed to find root UIViewController from "
                @"UISceneWillConnectNotification. Notification object has no windows property");
            return;
        }

        id windows = [notification.object performSelector:@selector(windows)];
        if (![windows isKindOfClass:[NSArray class]]) {
            SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: Failed to find root UIViewController "
                             @"from UISceneWillConnectNotification. Windows is not an array");
            return;
        }

        NSArray *windowList = windows;
        for (id window in windowList) {
            if ([window isKindOfClass:[UIWindow class]]
                && ((UIWindow *)window).rootViewController != nil) {
                [self
                    swizzleRootViewControllerAndDescendant:((UIWindow *)window).rootViewController];
            } else {
                SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: Failed to find root "
                                 @"UIViewController from UISceneWillConnectNotification. Window is "
                                 @"not a UIWindow class or the rootViewController is nil");
            }
        }
    }
}

- (BOOL)swizzleRootViewControllerFromUIApplication:(id<SentryUIApplication>)app
{
    if (app.delegate == nil) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: App delegate is nil. Skipping "
                         @"swizzleRootViewControllerFromAppDelegate.");
        return NO;
    }

    // Check if delegate responds to window, which it doesn't have to.
    if (![app.delegate respondsToSelector:@selector(window)]) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: UIApplicationDelegate.window is nil. "
                         @"Skipping swizzleRootViewControllerFromAppDelegate.");
        return NO;
    }

    if (app.delegate.window == nil) {
        SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling: UIApplicationDelegate.window is nil. "
                         @"Skipping swizzleRootViewControllerFromAppDelegate.");
        return NO;
    }

    UIViewController *rootViewController = app.delegate.window.rootViewController;
    if (rootViewController == nil) {
        SENTRY_LOG_DEBUG(
            @"UIViewControllerSwizziling: UIApplicationDelegate.window.rootViewController is nil. "
            @"Skipping swizzleRootViewControllerFromAppDelegate.");
        return NO;
    }

    [self swizzleRootViewControllerAndDescendant:rootViewController];

    return YES;
}

- (void)swizzleRootViewControllerAndDescendant:(UIViewController *)rootViewController
{
    NSArray<UIViewController *> *allViewControllers
        = rootViewController.sentry_descendantViewControllers;

    for (UIViewController *viewController in allViewControllers) {
        Class viewControllerClass = [viewController class];
        if (viewControllerClass != nil) {
            SENTRY_LOG_DEBUG(@"UIViewControllerSwizziling Calling swizzleRootViewController.");
            [self swizzleViewControllerSubClass:viewControllerClass];

            // We can't get the image name with the app delegate class for some apps. Therefore, we
            // use the rootViewController and its subclasses as a fallback.  The following method
            // ensures we don't swizzle ViewControllers of UIKit.
            [self swizzleUIViewControllersOfClassesInImageOf:viewControllerClass];
        }
    }
}

/**
 * We need to swizzle UIViewController 'loadView'
 * because we can`t do it for controllers that use Nib files
 * (see `swizzleLoadView` for more information).
 * SentryUIViewControllerPerformanceTracker makes sure we don't get two spans
 * if the loadView of an actual UIViewController is swizzled.
 */
- (void)swizzleUIViewController
{
    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerLoadView:self
                      callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

- (void)swizzleViewControllerSubClass:(Class)class
{
    if (![self shouldSwizzleViewController:class])
        return;

    // This are the five main functions related to UI creation in a view controller.
    // We are swizzling it to track anything that happens inside one of this functions.
    [self swizzleViewLayoutSubViews:class];
    [self swizzleLoadView:class];
    [self swizzleViewDidLoad:class];
    [self swizzleViewWillAppear:class];
    [self swizzleViewWillDisappear:class];
    [self swizzleViewDidAppear:class];
}

/**
 * For testing.
 */
- (BOOL)shouldSwizzleViewController:(Class)class
{
    return [self.inAppLogic isClassInApp:class];
}

- (void)swizzleLoadView:(Class)class
{
    // The UIViewController only searches for a nib file if you do not override the loadView method.
    // When swizzling the loadView of a custom UIViewController, the UIViewController doesn't search
    // for a nib file and doesn't load a view. This would lead to crashes as no view is loaded. As a
    // workaround, we skip swizzling the loadView and accept that the SKD doesn't create a span for
    // loadView if the UIViewController doesn't implement it.
    SEL selector = NSSelectorFromString(@"loadView");
    IMP viewControllerImp = class_getMethodImplementation([UIViewController class], selector);
    IMP classLoadViewImp = class_getMethodImplementation(class, selector);
    if (viewControllerImp == classLoadViewImp) {
        return;
    }

    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerLoadView:self
                      callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

- (void)swizzleViewDidLoad:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidLoad:self
                         callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

- (void)swizzleViewWillAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewWillAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewWillAppear:self
                            callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

- (void)swizzleViewDidAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidAppear:self
                           callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

- (void)swizzleViewWillDisappear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewWillDisappear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewWillDisappear:self
                               callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
}

- (void)swizzleViewLayoutSubViews:(Class)class
{
    SEL willSelector = NSSelectorFromString(@"viewWillLayoutSubviews");
    SentrySwizzleInstanceMethod(class, willSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewWillLayoutSubViews:self
                                    callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClass, (void *)willSelector);

    SEL didSelector = NSSelectorFromString(@"viewDidLayoutSubviews");
    SentrySwizzleInstanceMethod(class, didSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidLayoutSubViews:self
                                   callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClass, (void *)didSelector);
}

@end

#    pragma clang diagnostic pop
#endif
