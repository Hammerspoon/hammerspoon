#import "SentryLevelHelper.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryLevelMapper.h"

@implementation SentryLevelHelper

+ (NSUInteger)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb
{
    return breadcrumb.level;
}

+ (NSString *_Nonnull)getNameFor:(NSUInteger)level
{
    return nameForSentryLevel(level);
}

@end
