#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"
#    import "SentryIntegrationProtocol.h"

@interface SentryUIEventTrackingIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

@end

#endif // SENTRY_HAS_UIKIT
