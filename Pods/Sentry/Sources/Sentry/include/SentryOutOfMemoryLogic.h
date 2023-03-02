#import "SentryDefines.h"

@class SentryOptions, SentryCrashAdapter, SentryAppState, SentryFileManager, SentryAppStateManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryOutOfMemoryLogic : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper
                appStateManager:(SentryAppStateManager *)appStateManager;

- (BOOL)isOOM;

@end

NS_ASSUME_NONNULL_END
