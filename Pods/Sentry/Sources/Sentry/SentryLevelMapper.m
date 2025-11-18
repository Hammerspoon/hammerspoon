#import "SentryLevelMapper.h"
#import "SentrySwift.h"
NS_ASSUME_NONNULL_BEGIN

SentryLevel
sentryLevelForString(NSString *_Nullable string)
{
    return [SentryLevelHelper levelForName:string];
}

NSString *
nameForSentryLevel(SentryLevel level)
{
    return [SentryLevelHelper nameForLevel:level];
}

NS_ASSUME_NONNULL_END
