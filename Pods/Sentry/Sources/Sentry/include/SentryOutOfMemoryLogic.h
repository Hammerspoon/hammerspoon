#import "SentryDefines.h"

@class SentryOptions, SentryCrashAdapter, SentryAppState, SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryOutOfMemoryLogic : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper;

- (BOOL)isOOM;

#if SENTRY_HAS_UIKIT
- (SentryAppState *)buildCurrentAppState;
#endif

@end

NS_ASSUME_NONNULL_END
