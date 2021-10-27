#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@class SentryOptions, SentryDispatchQueueWrapper;

/**
 * Class is responsible to swizzle UI key methods
 * so Sentry can track UI performance.
 */
@interface SentryUIViewControllerSwizziling : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                  dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

- (void)start;

@end

#endif

NS_ASSUME_NONNULL_END
