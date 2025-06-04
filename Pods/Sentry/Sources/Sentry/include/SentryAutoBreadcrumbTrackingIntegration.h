#import "SentryBaseIntegration.h"
#import "SentryBreadcrumbDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * This automatically adds breadcrumbs for different user actions.
 */
@interface SentryAutoBreadcrumbTrackingIntegration
    : SentryBaseIntegration <SentryBreadcrumbDelegate>

@end

NS_ASSUME_NONNULL_END
