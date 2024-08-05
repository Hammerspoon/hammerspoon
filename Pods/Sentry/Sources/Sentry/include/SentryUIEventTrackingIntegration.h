#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"
#    import "SentrySwift.h"

@interface SentryUIEventTrackingIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

@end

#endif // SENTRY_HAS_UIKIT
