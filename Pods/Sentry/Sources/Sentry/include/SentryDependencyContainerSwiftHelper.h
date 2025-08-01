#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

// Some Swift code needs to access SentryDependencyContainer. To
// make that possible without requiring all of SentryDependencyContainer
// to be exposed to Swift this class is exposed to Swift
// and bridges some functionality from SentryDependencyContainer
@interface SentryDependencyContainerSwiftHelper : NSObject

#if SENTRY_HAS_UIKIT

+ (nullable NSArray<UIWindow *> *)windows;

#endif // SENTRY_HAS_UIKIT

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
