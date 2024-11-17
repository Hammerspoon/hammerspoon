#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentrySwift.h"

@class SentryDispatchQueueWrapper;
@class SentryAppStateManager;
@class SentryFramesTracker;

NS_ASSUME_NONNULL_BEGIN

/**
 * Tracks cold and warm app start time for iOS, tvOS, and Mac Catalyst. The logic for the different
 * app start types is based on https://developer.apple.com/videos/play/wwdc2019/423/. Cold start:
 * After reboot of the device, the app is not in memory and no process exists. Warm start: When the
 * app recently terminated, the app is partially in memory and no process exists.
 */
@interface SentryAppStartTracker : NSObject
SENTRY_NO_INIT

@property (nonatomic) BOOL isRunning;

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                             appStateManager:(SentryAppStateManager *)appStateManager
                               framesTracker:(SentryFramesTracker *)framesTracker
              enablePreWarmedAppStartTracing:(BOOL)enablePreWarmedAppStartTracing
                         enablePerformanceV2:(BOOL)enablePerformanceV2;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
