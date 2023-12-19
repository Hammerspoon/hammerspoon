#import "SentryFileManager.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryNSNotificationCenterWrapper;

@protocol SentryBreadcrumbDelegate;

@interface SentrySystemEventBreadcrumbs : NSObject
SENTRY_NO_INIT

- (instancetype)initWithFileManager:(SentryFileManager *)fileManager
       andNotificationCenterWrapper:(SentryNSNotificationCenterWrapper *)notificationCenterWrapper;

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate;

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate
            currentDevice:(nullable UIDevice *)currentDevice;
- (void)timezoneEventTriggered;

- (void)stop;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
