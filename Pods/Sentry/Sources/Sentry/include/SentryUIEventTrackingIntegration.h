#import "SentryBaseIntegration.h"
#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_HAS_UIKIT
@interface SentryUIEventTrackingIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

@end
#endif
NS_ASSUME_NONNULL_END
