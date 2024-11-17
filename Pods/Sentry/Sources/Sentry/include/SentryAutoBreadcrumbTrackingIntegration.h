#import "SentryBaseIntegration.h"
#import "SentryBreadcrumbDelegate.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * This automatically adds breadcrumbs for different user actions.
 */
@interface SentryAutoBreadcrumbTrackingIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryBreadcrumbDelegate>

@end

NS_ASSUME_NONNULL_END
