#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentryOptions, SentryCrashWrapper, SentryAppState, SentryFileManager, SentryAppStateManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryWatchdogTerminationLogic : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashWrapper *)crashAdapter
                appStateManager:(SentryAppStateManager *)appStateManager;

- (BOOL)isWatchdogTermination;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
