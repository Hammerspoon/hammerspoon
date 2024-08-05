#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"
#    import "SentrySwift.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryFramesTrackingIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
