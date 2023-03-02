#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This automatically adds breadcrumbs for different user actions.
 */
@interface SentryAutoBreadcrumbTrackingIntegration : NSObject <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END
