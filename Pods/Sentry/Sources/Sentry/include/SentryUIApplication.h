#import "SentryApplication.h"
#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class UIApplication;
@class UIScene;
@class UIWindow;
@class UIViewController;
@class SentryNSNotificationCenterWrapper;
@class SentryDispatchQueueWrapper;
@protocol UIApplicationDelegate;

typedef NS_ENUM(NSInteger, UIApplicationState);

NS_ASSUME_NONNULL_BEGIN

/**
 * A helper tool to retrieve informations from the application instance.
 */
@interface SentryUIApplication : NSObject <SentryApplication>
SENTRY_NO_INIT

- (instancetype)
    initWithNotificationCenterWrapper:(SentryNSNotificationCenterWrapper *)notificationCenterWrapper
                 dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
