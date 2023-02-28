#import "SentryDefines.h"
#import "SentryObjCRuntimeWrapper.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentryDispatchQueueWrapper, SentrySubClassFinder, SentryProcessInfoWrapper;

/**
 * This is a protocol to define which properties and methods the swizzler required from
 * UIApplication. This way, instead of relying on UIApplication, we can test with a mock class.
 */
@protocol SentryUIApplication

@property (nullable, nonatomic, assign) id<UIApplicationDelegate> delegate;

@end

/**
 * Class is responsible to swizzle UI key methods
 * so Sentry can track UI performance.
 */
@interface SentryUIViewControllerSwizzling : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                  dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
             objcRuntimeWrapper:(id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
                 subClassFinder:(SentrySubClassFinder *)subClassFinder
             processInfoWrapper:(SentryProcessInfoWrapper *)processInfoWrapper;

- (void)start;

@end
NS_ASSUME_NONNULL_END

#endif
