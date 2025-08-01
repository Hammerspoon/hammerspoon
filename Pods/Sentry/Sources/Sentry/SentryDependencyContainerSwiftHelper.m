#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryDependencyContainer.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"
#import "SentryUIApplication.h"

@implementation SentryDependencyContainerSwiftHelper

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return SentryDependencyContainer.sharedInstance.application.windows;
}

#endif // SENTRY_HAS_UIKIT

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
{
    return SentryDependencyContainer.sharedInstance.objcRuntimeWrapper;
}

+ (SentryHub *)currentHub
{
    return SentrySDKInternal.currentHub;
}

@end
