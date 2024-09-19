#import "SentryLevelHelper.h"
#import "SentryBreadcrumb+Private.h"

NSUInteger
sentry_breadcrumbLevel(SentryBreadcrumb *breadcrumb)
{
    return breadcrumb.level;
}
