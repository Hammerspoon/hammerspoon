#import "SentryLevelMapper.h"
#import "SentrySwift.h"
NS_ASSUME_NONNULL_BEGIN

SentryLevel
sentryLevelForString(NSString *string)
{
    return [SentryLevelHelper levelForName:string];
}

NSString *
nameForSentryLevel(SentryLevel level)
{
    return [SentryLevelHelper nameForLevel:level];
}

NS_ASSUME_NONNULL_END
