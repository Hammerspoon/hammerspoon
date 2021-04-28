#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySwizzle.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    import <Cocoa/Cocoa.h>
#endif

@implementation SentryBreadcrumbTracker

- (void)start
{
    [self addEnabledCrumb];
    [self swizzleSendAction];
    [self swizzleViewDidAppear];
    [self trackApplicationUIKitNotifications];
}

- (void)stop
{
    // This is a noop because the notifications are registered via blocks and monkey patching
    // which are both super hard to clean up.
    // Either way, all these are guarded by checking the client of the current hub, which
    // we remove when uninstalling the SDK.
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
    [SentryLog logWithMessage:@"NO UIKit, OSX and Catalyst -> [SentryBreadcrumbTracker "
                              @"trackApplicationUIKitNotifications] does nothing."
                     andLevel:kSentryLevelDebug];
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

- (void)swizzleSendAction
{
#if SENTRY_HAS_UIKIT

    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    SentrySwizzleInstanceMethod(UIApplication.class, selector, SentrySWReturnType(BOOL),
        SentrySWArguments(SEL action, id target, id sender, UIEvent * event), SentrySWReplacement({
            if (nil != [SentrySDK.currentHub getClient]) {
                NSDictionary *data = nil;
                for (UITouch *touch in event.allTouches) {
                    if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                        data = @ { @"view" : [NSString stringWithFormat:@"%@", touch.view] };
                    }
                }
                SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                                         category:@"touch"];
                crumb.type = @"user";
                crumb.message = [NSString stringWithFormat:@"%s", sel_getName(action)];
                crumb.data = data;
                [SentrySDK addBreadcrumb:crumb];
            }
            return SentrySWCallOriginal(action, target, sender, event);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#    pragma clang diagnostic pop
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker "
                              @"swizzleSendAction] does nothing."
                     andLevel:kSentryLevelDebug];
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
                NSString *viewControllerName = [SentryBreadcrumbTracker
                    sanitizeViewControllerName:[NSString stringWithFormat:@"%@", self]];
                crumb.data = @ { @"screen" : viewControllerName };

                // Adding crumb via the SDK calls SentryBeforeBreadcrumbCallback
                [SentrySDK addBreadcrumb:crumb];
                [SentrySDK.currentHub configureScope:^(SentryScope *_Nonnull scope) {
                    [scope setExtraValue:viewControllerName forKey:@"__sentry_transaction"];
                }];
            }
            SentrySWCallOriginal(animated);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewDidAppearKey);
#    pragma clang diagnostic pop
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker "
                              @"swizzleViewDidAppear] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

+ (NSRegularExpression *)viewControllerRegex
{
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        NSString *pattern = @"[<.](\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}

+ (NSString *)sanitizeViewControllerName:(NSString *)controller
{
    NSRange searchedRange = NSMakeRange(0, [controller length]);
    NSArray *matches = [[self.class viewControllerRegex] matchesInString:controller
                                                                 options:0
                                                                   range:searchedRange];
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        [strings addObject:[controller substringWithRange:[match rangeAtIndex:1]]];
    }
    if ([strings count] > 0) {
        return [strings componentsJoinedByString:@"."];
    }
    return controller;
}

@end
