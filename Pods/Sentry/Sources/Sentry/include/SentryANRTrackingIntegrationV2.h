#import "SentryANRTrackerV2.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"
#    import "SentrySwift.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryANRExceptionTypeV2 = @"App Hanging";

@interface SentryANRTrackingIntegrationV2
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryANRTrackerV2Delegate>

- (void)pauseAppHangTracking;
- (void)resumeAppHangTracking;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
