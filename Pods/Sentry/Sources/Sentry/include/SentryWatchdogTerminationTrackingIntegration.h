#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryANRTracker.h"
#    import "SentryBaseIntegration.h"
#    import "SentryIntegrationProtocol.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryWatchdogTerminationTrackingIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryANRTrackerDelegate>

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
