#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"

@class SentryDispatchQueueWrapper, SentryAppStateManager, SentrySysctl;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/**
 * Tracks cold and warm app start time for iOS, tvOS, and Mac Catalyst. The logic for the different
 * app start types is based on https://developer.apple.com/videos/play/wwdc2019/423/. Cold start:
 * After reboot of the device, the app is not in memory and no process exists. Warm start: When the
 * app recently terminated, the app is partially in memory and no process exists.
 */
@interface SentryAppStartTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                       dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                            appStateManager:(SentryAppStateManager *)appStateManager
                                     sysctl:(SentrySysctl *)sysctl;

- (void)start;
- (void)stop;

@end

#endif

NS_ASSUME_NONNULL_END
