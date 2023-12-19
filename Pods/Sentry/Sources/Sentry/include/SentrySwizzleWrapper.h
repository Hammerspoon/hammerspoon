#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentrySwizzleSendActionCallback)(
    NSString *actionName, _Nullable id target, _Nullable id sender, UIEvent *_Nullable event);

/**
 * A wrapper around swizzling for testability and to only swizzle once when multiple implementations
 * need to be called for the same swizzled method.
 */
@interface SentrySwizzleWrapper : NSObject

- (void)swizzleSendAction:(SentrySwizzleSendActionCallback)callback forKey:(NSString *)key;

- (void)removeSwizzleSendActionForKey:(NSString *)key;

/**
 * For testing purposes.
 */
- (void)removeAllCallbacks;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
