#import "SentryLevelHelper.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryEvent.h"

@implementation SentryLevelBridge : NSObject
+ (NSUInteger)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb
{
    return breadcrumb.level;
}

+ (void)setBreadcrumbLevel:(SentryBreadcrumb *)breadcrumb level:(NSUInteger)level
{
    breadcrumb.level = level;
}

+ (void)setBreadcrumbLevelOnEvent:(SentryEvent *)event level:(NSUInteger)level
{
    event.level = level;
}

@end
