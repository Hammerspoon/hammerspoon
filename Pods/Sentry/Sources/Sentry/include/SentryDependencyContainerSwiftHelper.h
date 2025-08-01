#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif // SENTRY_HAS_UIKIT

@protocol SentryObjCRuntimeWrapper;
@class SentryHub;

NS_ASSUME_NONNULL_BEGIN

// Some Swift code needs to access Sentry types that we don’t want to completely
// expose to Swift. This class is exposed to Swift
// and bridges some functionality from without importing large amounts of the
// codebase to Swift.
@interface SentryDependencyContainerSwiftHelper : NSObject

#if SENTRY_HAS_UIKIT

+ (nullable NSArray<UIWindow *> *)windows;

#endif // SENTRY_HAS_UIKIT

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block;
+ (id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper;
+ (SentryHub *)currentHub;

@end

NS_ASSUME_NONNULL_END
