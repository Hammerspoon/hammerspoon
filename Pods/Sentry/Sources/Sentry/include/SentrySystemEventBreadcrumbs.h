#import "SentryCurrentDateProvider.h"
#import "SentryFileManager.h"
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryNSNotificationCenterWrapper;

@protocol SentrySystemEventBreadcrumbsDelegate;

@interface SentrySystemEventBreadcrumbs : NSObject
SENTRY_NO_INIT

- (instancetype)initWithFileManager:(SentryFileManager *)fileManager
             andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
       andNotificationCenterWrapper:(SentryNSNotificationCenterWrapper *)notificationCenterWrapper;

- (void)startWithDelegate:(id<SentrySystemEventBreadcrumbsDelegate>)delegate;

#if TARGET_OS_IOS
- (void)startWithDelegate:(id<SentrySystemEventBreadcrumbsDelegate>)delegate
            currentDevice:(nullable UIDevice *)currentDevice;
- (void)timezoneEventTriggered;
#endif

- (void)stop;

@end

@protocol SentrySystemEventBreadcrumbsDelegate <NSObject>

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

@end

NS_ASSUME_NONNULL_END
