#import "SentryUIViewControllerSwizzling.h"
#import "SentryDefaultObjCRuntimeWrapper.h"
#import "SentryLog.h"
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

@end

@implementation SentryUIViewControllerSwizzling

- (instancetype)initWithOptions:(SentryOptions *)options
                  dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
{
    if (self = [super init]) {
        self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                            inAppExcludes:options.inAppExcludes];
        self.dispatchQueue = dispatchQueue;
    }

    return self;
}

- (void)start
{
    [self swizzleRootViewController];

    SentrySubClassFinder *subClassFinder = [[SentrySubClassFinder alloc]
        initWithDispatchQueue:self.dispatchQueue
           objcRuntimeWrapper:[[SentryDefaultObjCRuntimeWrapper alloc] init]];

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
    [subClassFinder
        actOnSubclassesOf:[UIViewController class]
                    block:^(Class class) { [self swizzleViewControllerSubClass:class]; }];

    [self swizzleUIViewController];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

/**
 * If an app targets, for example, iOS 13 or lower, the UIKit inits the initial/root view controller
 * before the SentrySDK is initialized. Therefore, we manually call swizzle here not to lose
 * auto-generated transactions for the initial view controller. As we use
 * SentrySwizzleModeOncePerClassAndSuperclasses, we don't have to worry about swizzling twice. We
 * could also use objc_getClassList to lookup sub classes of UIViewController, but the lookup can
 * take around 60ms, which is not acceptable.
 */
- (void)swizzleRootViewController
{
    if (![UIApplication respondsToSelector:@selector(sharedApplication)]) {
        NSString *message = @"UIViewControllerSwizziling: UIApplication doesn't respont to "
                            @"sharedApplication. Skipping swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    UIApplication *app = [UIApplication performSelector:@selector(sharedApplication)];

    if (app == nil) {
        NSString *message = @"UIViewControllerSwizziling: UIApplication is nil. Skipping "
                            @"swizzleRootViewController.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return;
    }

    if (![self swizzleRootViewControllerFromUIApplication:app]) {
        NSString *message
            = @"UIViewControllerSwizziling: Fail to find root UIViewController from "
              @"UIApplicationDelegate. Trying to use UISceneWillConnectNotification notification.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];

        if (@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *)) {
            [NSNotificationCenter.defaultCenter
                addObserver:self
                   selector:@selector(swizzleRootViewControllerFromSceneDelegateNotification:)
                       name:UISceneWillConnectNotification
                     object:nil];
        } else {
            message = @"UIViewControllerSwizziling: iOS version older then 13."
                      @"There is no UISceneWillConnectNotification notification. Could not find a "
                      @"rootViewController";

            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        }
    }
}

/**
 * If the iOS version is 13 or newer, and the project does not use a custom Window initialization
 * the app uses a UIScenes to manage windows instead of the old AppDelegate.
 * We wait for the first scene to connect to the app in order to find the rootViewController.
 */
- (void)swizzleRootViewControllerFromSceneDelegateNotification:(NSNotification *)notification
{
    if (@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *)) {
        if (![notification.name isEqualToString:UISceneWillConnectNotification])
            return;

        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:UISceneWillConnectNotification
                                                    object:nil];

        // The object of a UISceneWillConnectNotification should be a NSWindowScene
        if (![notification.object respondsToSelector:@selector(windows)]) {
            NSString *message
                = @"UIViewControllerSwizziling: Fail to find root UIViewController from "
                  @"UISceneWillConnectNotification. Notification object has no windows property";
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
            return;
        }

        id windows = [notification.object performSelector:@selector(windows)];
        if (![windows isKindOfClass:[NSArray class]]) {
            NSString *message
                = @"UIViewControllerSwizziling: Fail to find root UIViewController from "
                  @"UISceneWillConnectNotification. Windows is not an array";
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
            return;
        }

        NSArray *windowList = windows;
        for (id window in windowList) {
            if ([window isKindOfClass:[UIWindow class]]
                && ((UIWindow *)window).rootViewController != nil) {
                [self
                    swizzleRootViewControllerAndDescendant:((UIWindow *)window).rootViewController];
            }
        }
    }
}

- (BOOL)swizzleRootViewControllerFromUIApplication:(id<SentryUIApplication>)app
{
    if (app.delegate == nil) {
        NSString *message = @"UIViewControllerSwizziling: UIApplicationDelegate is nil. Skipping "
                            @"swizzleRootViewControllerFromAppDelegate.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return NO;
    }

    // Check if delegate responds to window, which it doesn't have to.
    if (![app.delegate respondsToSelector:@selector(window)]) {
        NSString *message = @"UIViewControllerSwizziling: UIApplicationDelegate.window is nil. "
                            @"Skipping swizzleRootViewControllerFromAppDelegate.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return NO;
    }

    if (app.delegate.window == nil) {
        NSString *message = @"UIViewControllerSwizziling: UIApplicationDelegate.window is nil. "
                            @"Skipping swizzleRootViewControllerFromAppDelegate.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return NO;
    }

    UIViewController *rootViewController = app.delegate.window.rootViewController;
    if (rootViewController == nil) {
        NSString *message = @"UIViewControllerSwizziling: "
                            @"UIApplicationDelegate.window.rootViewController is nil. "
                            @"Skipping swizzleRootViewControllerFromAppDelegate.";
        [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
        return NO;
    }

    [self swizzleRootViewControllerAndDescendant:rootViewController];

    return YES;
}

- (void)swizzleRootViewControllerAndDescendant:(UIViewController *)rootViewController
{
    NSArray<UIViewController *> *allViewControllers = rootViewController.descendantViewControllers;

    for (UIViewController *viewController in allViewControllers) {
        Class viewControllerClass = [viewController class];
        if (viewControllerClass != nil) {
            NSString *message = @"UIViewControllerSwizziling Calling swizzleRootViewController.";
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];

            [self swizzleViewControllerSubClass:viewControllerClass];
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
