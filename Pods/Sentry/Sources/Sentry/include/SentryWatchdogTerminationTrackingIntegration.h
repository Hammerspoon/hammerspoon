#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import "SentryBaseIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryWatchdogTerminationTrackingIntegration : SentryBaseIntegration

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
