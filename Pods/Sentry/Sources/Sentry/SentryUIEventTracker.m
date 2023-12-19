#import <SentryUIEventTracker.h>

#if SENTRY_HAS_UIKIT

#    import "SentrySwizzleWrapper.h"
#    import <SentryDependencyContainer.h>
#    import <SentryLog.h>
#    import <SentrySpanOperations.h>
#    import <SentryUIEventTrackerMode.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryUIEventTrackerSwizzleSendAction
    = @"SentryUIEventTrackerSwizzleSendAction";

@interface
SentryUIEventTracker ()

@property (nonatomic, strong) id<SentryUIEventTrackerMode> uiEventTrackerMode;

@end

@implementation SentryUIEventTracker

- (instancetype)initWithMode:(id<SentryUIEventTrackerMode>)mode
{
    if (self = [super init]) {
        self.uiEventTrackerMode = mode;
    }
    return self;
}

- (void)start
{
    [SentryDependencyContainer.sharedInstance.swizzleWrapper
        swizzleSendAction:^(NSString *action, id target, id sender, UIEvent *event) {
            [self sendActionCallback:action target:target sender:sender event:event];
        }
                   forKey:SentryUIEventTrackerSwizzleSendAction];
}

- (void)sendActionCallback:(NSString *)action
                    target:(nullable id)target
                    sender:(nullable id)sender
                     event:(nullable UIEvent *)event
{
    if (target == nil) {
        SENTRY_LOG_DEBUG(@"Target was nil for action %@; won't capture in transaction "
                         @"(sender: %@; event: %@)",
            action, sender, event);
        return;
    }

    if (sender == nil) {
        SENTRY_LOG_DEBUG(@"Sender was nil for action %@; won't capture in transaction "
                         @"(target: %@; event: %@)",
            action, sender, event);
        return;
    }

    // When using an application delegate with SwiftUI we receive touch events here, but
    // the target class name looks something like
    // _TtC7SwiftUIP33_64A26C7A8406856A733B1A7B593971F711Coordinator.primaryActionTriggered,
    // which is unacceptable for a transaction name. Ideally, we should somehow shorten
    // the long name.

    NSString *targetClass = NSStringFromClass([target class]);
    if ([targetClass containsString:@"SwiftUI"]) {
        SENTRY_LOG_DEBUG(@"Won't record transaction for SwiftUI target event.");
        return;
    }

    NSString *actionName = [self getTransactionName:action target:targetClass];
    NSString *operation = [self getOperation:sender];

    NSString *accessibilityIdentifier = nil;
    if ([[sender class] isSubclassOfClass:[UIView class]]) {
        UIView *view = sender;
        accessibilityIdentifier = view.accessibilityIdentifier;
    }

    [self.uiEventTrackerMode handleUIEvent:actionName
                                 operation:operation
                   accessibilityIdentifier:accessibilityIdentifier];
}

- (void)stop
{
    [SentryDependencyContainer.sharedInstance.swizzleWrapper
        removeSwizzleSendActionForKey:SentryUIEventTrackerSwizzleSendAction];
}

- (NSString *)getOperation:(id)sender
{
    Class senderClass = [sender class];
    if ([senderClass isSubclassOfClass:[UIButton class]] ||
        [senderClass isSubclassOfClass:[UIBarButtonItem class]] ||
        [senderClass isSubclassOfClass:[UISegmentedControl class]] ||
        [senderClass isSubclassOfClass:[UIPageControl class]]) {
        return SentrySpanOperationUIActionClick;
    }

    return SentrySpanOperationUIAction;
}

/**
 * The action is an Objective-C selector and might look weird for Swift developers. Therefore we
 * convert the selector to a Swift appropriate format aligned with the Swift #selector syntax.
 * method:first:second:third: gets converted to method(first:second:third:)
 */
- (NSString *)getTransactionName:(NSString *)action target:(NSString *)target
{
    NSArray<NSString *> *components = [action componentsSeparatedByString:@":"];
    if (components.count > 2) {
        NSMutableString *result =
            [[NSMutableString alloc] initWithFormat:@"%@.%@(", target, components.firstObject];

        for (int i = 1; i < (components.count - 1); i++) {
            [result appendFormat:@"%@:", components[i]];
        }

        [result appendFormat:@")"];

        return result;
    }

    return [NSString stringWithFormat:@"%@.%@", target, components.firstObject];
}

+ (BOOL)isUIEventOperation:(NSString *)operation
{
    if ([operation isEqualToString:SentrySpanOperationUIAction]) {
        return YES;
    }
    if ([operation isEqualToString:SentrySpanOperationUIActionClick]) {
        return YES;
    }
    return NO;
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
