#import "SentrySwizzleWrapper.h"
#import "SentryLog.h"
#import "SentrySwizzle.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySwizzleWrapper

static NSMutableDictionary<NSString *, SentrySwizzleSendActionCallback>
    *sentrySwizzleSendActionCallbacks;

+ (void)initialize
{
    if (self == [SentrySwizzleWrapper class]) {
        sentrySwizzleSendActionCallbacks = [NSMutableDictionary new];
    }
}

- (void)swizzleSendAction:(SentrySwizzleSendActionCallback)callback forKey:(NSString *)key
{
    // We need to make a copy of the block to avoid ARC of autoreleasing it.
    sentrySwizzleSendActionCallbacks[key] = [callback copy];
    SENTRY_LOG_DEBUG(@"Swizzling sendAction for %@", key);

    if (sentrySwizzleSendActionCallbacks.count != 1) {
        return;
    }

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    SentrySwizzleInstanceMethod(UIApplication, selector, SentrySWReturnType(BOOL),
        SentrySWArguments(SEL action, id target, id sender, UIEvent * event), SentrySWReplacement({
            [SentrySwizzleWrapper sendActionCalled:action target:target sender:sender event:event];
            return SentrySWCallOriginal(action, target, sender, event);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#    pragma clang diagnostic pop
}

- (void)removeSwizzleSendActionForKey:(NSString *)key
{
    [sentrySwizzleSendActionCallbacks removeObjectForKey:key];
}

/**
 * For testing. We want the swizzling block above to call a static function to avoid having a block
 * reference to an instance of this class.
 */
+ (void)sendActionCalled:(SEL)action target:(id)target sender:(id)sender event:(UIEvent *)event
{
    for (SentrySwizzleSendActionCallback callback in sentrySwizzleSendActionCallbacks.allValues) {
        callback([NSString stringWithFormat:@"%s", sel_getName(action)], target, sender, event);
    }
}

/**
 * For testing.
 */
- (NSDictionary<NSString *, SentrySwizzleSendActionCallback> *)swizzleSendActionCallbacks
{
    return sentrySwizzleSendActionCallbacks;
}

- (void)removeAllCallbacks
{
    [sentrySwizzleSendActionCallbacks removeAllObjects];
}

// For test purpose
+ (BOOL)hasCallbacks
{
    return sentrySwizzleSendActionCallbacks.count > 0;
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
