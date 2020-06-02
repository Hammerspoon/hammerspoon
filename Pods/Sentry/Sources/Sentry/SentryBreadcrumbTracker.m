#import "SentryClient.h"
#import "SentryHub.h"
#import "SentrySDK.h"
#import "SentryDefines.h"
#import "SentrySwizzle.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryLog.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

@implementation SentryBreadcrumbTracker

- (void)start {
    [self addEnabledCrumb];
    [self swizzleSendAction];
    [self swizzleViewDidAppear];
    [self trackApplicationUIKitNotifications];
}

- (void)trackApplicationUIKitNotifications {
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    if (nil != [SentrySDK.currentHub getClient]) {
                                                        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelWarning category:@"device.memory"];
                                                        crumb.type = @"system";
                                                        crumb.message = @"Low memory";
                                                        [SentrySDK addBreadcrumb:crumb];
                                                    }
                                                }];
    
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [self addBreadcrumbWithType: @"navigation"
                                                                   withCategory: @"app.lifecycle"
                                                                      withLevel: kSentryLevelInfo
                                                                    withDataKey: @"state"
                                                                  withDataValue: @"background"];
                                                }];
    
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [self addBreadcrumbWithType: @"navigation"
                                                                   withCategory: @"app.lifecycle"
                                                                      withLevel: kSentryLevelInfo
                                                                    withDataKey: @"state"
                                                                  withDataValue: @"foreground"];
                                                }];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker trackApplicationUIKitNotifications] does nothing." andLevel:kSentryLogLevelDebug];
#endif
}

- (void)addBreadcrumbWithType:(NSString *)type
                 withCategory:(NSString *)category
                    withLevel:(SentryLevel *)level
                  withDataKey:(NSString *)key
                withDataValue:(NSString *)value {
    if (nil != [SentrySDK.currentHub getClient]) {
        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:level category:category];
        crumb.type = type;
        crumb.data = @{key: value};
        [SentrySDK addBreadcrumb:crumb];
    }
}

- (void)addEnabledCrumb {
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo category:@"started"];
    crumb.type = @"debug";
    crumb.message = @"Breadcrumb Tracking";
    [SentrySDK addBreadcrumb:crumb];
}

- (void)swizzleSendAction {
#if SENTRY_HAS_UIKIT
    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    //    - (BOOL)sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender forEvent:(nullable UIEvent *)event;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    SentrySwizzleInstanceMethod(UIApplication.class,
            selector,
            SentrySWReturnType(BOOL),
            SentrySWArguments(SEL action, id target, id sender, UIEvent * event),
            SentrySWReplacement({
                    if (nil != [SentrySDK.currentHub getClient]) {
                        NSDictionary *data = [NSDictionary new];
                        for (UITouch *touch in event.allTouches) {
                            if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                                data = @{@"view": [NSString stringWithFormat:@"%@", touch.view]};
                            }
                        }
                        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo category:@"touch"];
                        crumb.type = @"user";
                        crumb.message = [NSString stringWithFormat:@"%s", sel_getName(action)];
                        crumb.data = data;
                        [SentrySDK addBreadcrumb:crumb];
                    }
                    return SentrySWCallOriginal(action, target, sender, event);
            }), SentrySwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker swizzleSendAction] does nothing." andLevel:kSentryLogLevelDebug];
#endif
}

- (void)swizzleViewDidAppear {
#if SENTRY_HAS_UIKIT
    static const void *swizzleViewDidAppearKey = &swizzleViewDidAppearKey;
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(UIViewController.class,
            selector,
            SentrySWReturnType(void),
            SentrySWArguments(BOOL animated),
            SentrySWReplacement({
                    if (nil != [SentrySDK.currentHub getClient]) {
                        SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo category:@"ui.lifecycle"];
                        crumb.type = @"navigation";
                        NSString *viewControllerName = [SentryBreadcrumbTracker sanitizeViewControllerName:[NSString stringWithFormat:@"%@", self]];
                        crumb.data = @{@"screen": viewControllerName};

                        [SentrySDK.currentHub configureScope:^(SentryScope * _Nonnull scope) {
                            [scope addBreadcrumb:crumb];
                            [scope setExtraValue:viewControllerName forKey:@"__sentry_transaction"];
                        }];
                    }
                    SentrySWCallOriginal(animated);
            }), SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewDidAppearKey);
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker swizzleViewDidAppear] does nothing." andLevel:kSentryLogLevelDebug];
#endif
}

+ (NSRegularExpression *)viewControllerRegex {
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        NSString *pattern = @"[<.](\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}

+ (NSString *)sanitizeViewControllerName:(NSString *)controller {
    NSRange searchedRange = NSMakeRange(0, [controller length]);
    NSArray *matches = [[self.class viewControllerRegex] matchesInString:controller options:0 range:searchedRange];
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
