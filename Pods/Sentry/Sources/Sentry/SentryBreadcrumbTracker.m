#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySwift.h"
#import "SentrySwizzle.h"
#import "SentrySwizzleWrapper.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryBreadcrumbTrackerSwizzleSendAction
    = @"SentryBreadcrumbTrackerSwizzleSendAction";

@interface
SentryBreadcrumbTracker ()

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;

@end

@implementation SentryBreadcrumbTracker

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper
{
    if (self = [super init]) {
        self.swizzleWrapper = swizzleWrapper;
    }
    return self;
}

- (void)start
{
    [self addEnabledCrumb];
    [self trackApplicationUIKitNotifications];
}

- (void)startSwizzle
{
    [self swizzleSendAction];
    [self swizzleViewDidAppear];
}

- (void)stop
{
    // All breadcrumbs are guarded by checking the client of the current hub, which we remove when
    // uninstalling the SDK. Therefore, we don't clean up everything.
#if SENTRY_HAS_UIKIT
    [self.swizzleWrapper removeSwizzleSendActionForKey:SentryBreadcrumbTrackerSwizzleSendAction];
#endif
}

- (void)trackApplicationUIKitNotifications
{
#if SENTRY_HAS_UIKIT
    NSNotificationName foregroundNotificationName = UIApplicationDidBecomeActiveNotification;
    NSNotificationName backgroundNotificationName = UIApplicationDidEnterBackgroundNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName foregroundNotificationName = NSApplicationDidBecomeActiveNotification;
    // Will resign Active notification is the nearest one to
    // UIApplicationDidEnterBackgroundNotification
    NSNotificationName backgroundNotificationName = NSApplicationWillResignActiveNotification;
#else
    SENTRY_LOG_DEBUG(@"NO UIKit, OSX and Catalyst -> [SentryBreadcrumbTracker "
                     @"trackApplicationUIKitNotifications] does nothing.");
#endif

    // not available for macOS
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter
        addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    if (nil != [SentrySDK.currentHub getClient]) {
                        SentryBreadcrumb *crumb =
                            [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelWarning
                                                           category:@"device.event"];
                        crumb.type = @"system";
                        crumb.data = @ { @"action" : @"LOW_MEMORY" };
                        crumb.message = @"Low memory";
                        [SentrySDK addBreadcrumb:crumb];
                    }
                }];
#endif

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    [NSNotificationCenter.defaultCenter addObserverForName:backgroundNotificationName
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [self addBreadcrumbWithType:@"navigation"
                                                                   withCategory:@"app.lifecycle"
                                                                      withLevel:kSentryLevelInfo
                                                                    withDataKey:@"state"
                                                                  withDataValue:@"background"];
                                                }];

    [NSNotificationCenter.defaultCenter addObserverForName:foregroundNotificationName
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [self addBreadcrumbWithType:@"navigation"
                                                                   withCategory:@"app.lifecycle"
                                                                      withLevel:kSentryLevelInfo
                                                                    withDataKey:@"state"
                                                                  withDataValue:@"foreground"];
                                                }];
#endif
}

- (void)addBreadcrumbWithType:(NSString *)type
                 withCategory:(NSString *)category
                    withLevel:(SentryLevel)level
                  withDataKey:(NSString *)key
                withDataValue:(NSString *)value
{
    if (nil != [SentrySDK.currentHub getClient]) {
        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:level category:category];
        crumb.type = type;
        crumb.data = @{ key : value };
        [SentrySDK addBreadcrumb:crumb];
    }
}

- (void)addEnabledCrumb
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"started"];
    crumb.type = @"debug";
    crumb.message = @"Breadcrumb Tracking";
    [SentrySDK addBreadcrumb:crumb];
}

#if SENTRY_HAS_UIKIT
+ (BOOL)avoidSender:(id)sender forTarget:(id)target action:(NSString *)action
{
    if ([sender isKindOfClass:UITextField.self]) {
        // This is required to avoid creating breadcrumbs for every key pressed in a text field.
        // Textfield may invoke many types of event, in order to check if is a
        // `UIControlEventEditingChanged` we need to compare the current action to all events
        // attached to the control. This may cause a false negative if the developer is using the
        // same action for different events, but this trade off is acceptable because using the same
        // action for `.editingChanged` and another event is not supposed to happen.
        UITextField *textField = sender;
        NSArray<NSString *> *actions = [textField actionsForTarget:target
                                                   forControlEvent:UIControlEventEditingChanged];
        return [actions containsObject:action];
    }
    return false;
}
#endif

- (void)swizzleSendAction
{
#if SENTRY_HAS_UIKIT
    [self.swizzleWrapper
        swizzleSendAction:^(NSString *action, id target, id sender, UIEvent *event) {
            if ([SentrySDK.currentHub getClient] == nil ||
                [SentryBreadcrumbTracker avoidSender:sender forTarget:target action:action]) {
                return;
            }

            NSDictionary *data = nil;
            for (UITouch *touch in event.allTouches) {
                if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                    data = [SentryBreadcrumbTracker extractDataFromView:touch.view];
                }
            }

            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                                     category:@"touch"];
            crumb.type = @"user";
            crumb.message = action;
            crumb.data = data;
            [SentrySDK addBreadcrumb:crumb];
        }
                   forKey:SentryBreadcrumbTrackerSwizzleSendAction];

#else
    SENTRY_LOG_DEBUG(@"NO UIKit -> [SentryBreadcrumbTracker swizzleSendAction] does nothing.");
#endif
}

- (void)swizzleViewDidAppear
{
#if SENTRY_HAS_UIKIT

    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    static const void *swizzleViewDidAppearKey = &swizzleViewDidAppearKey;
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            if (nil != [SentrySDK.currentHub getClient]) {
                SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                                         category:@"ui.lifecycle"];
                crumb.type = @"navigation";
                crumb.data = [SentryBreadcrumbTracker fetchInfoAboutViewController:self];

                // Adding crumb via the SDK calls SentryBeforeBreadcrumbCallback
                [SentrySDK addBreadcrumb:crumb];
            }
            SentrySWCallOriginal(animated);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewDidAppearKey);
#    pragma clang diagnostic pop
#else
    SENTRY_LOG_DEBUG(@"NO UIKit -> [SentryBreadcrumbTracker swizzleViewDidAppear] does nothing.");
#endif
}

#if SENTRY_HAS_UIKIT
+ (NSDictionary *)extractDataFromView:(UIView *)view
{
    NSMutableDictionary *result =
        @{ @"view" : [NSString stringWithFormat:@"%@", view] }.mutableCopy;

    if (view.tag > 0) {
        [result setValue:[NSNumber numberWithInteger:view.tag] forKey:@"tag"];
    }

    if (view.accessibilityIdentifier && ![view.accessibilityIdentifier isEqualToString:@""]) {
        [result setValue:view.accessibilityIdentifier forKey:@"accessibilityIdentifier"];
    }

    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        if (button.currentTitle && ![button.currentTitle isEqual:@""]) {
            [result setValue:[button currentTitle] forKey:@"title"];
        }
    }

    return result;
}

+ (NSDictionary *)fetchInfoAboutViewController:(UIViewController *)controller
{
    NSMutableDictionary *info = @{}.mutableCopy;

    info[@"screen"] = [SwiftDescriptor getObjectClassName:controller];

    if ([controller.navigationItem.title length] != 0) {
        info[@"title"] = controller.navigationItem.title;
    } else if ([controller.title length] != 0) {
        info[@"title"] = controller.title;
    }

    info[@"beingPresented"] = controller.beingPresented ? @"true" : @"false";

    if (controller.presentingViewController != nil) {
        info[@"presentingViewController"] =
            [SwiftDescriptor getObjectClassName:controller.presentingViewController];
    }

    if (controller.parentViewController != nil) {
        info[@"parentViewController"] =
            [SwiftDescriptor getObjectClassName:controller.parentViewController];
    }

    if (controller.view.window != nil) {
        info[@"window"] = controller.view.window.description;
        info[@"window_isKeyWindow"] = controller.view.window.isKeyWindow ? @"true" : @"false";
        info[@"window_windowLevel"] =
            [NSString stringWithFormat:@"%f", controller.view.window.windowLevel];
        info[@"is_window_rootViewController"]
            = controller.view.window.rootViewController == controller ? @"true" : @"false";
    }

    return info;
}
#endif

@end

NS_ASSUME_NONNULL_END
