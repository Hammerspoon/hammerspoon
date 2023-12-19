#import "SentryCurrentDateProvider.h"
#import "SentryTime.h"

@implementation SentryCurrentDateProvider

- (NSDate *_Nonnull)date
{
    return [NSDate date];
}

- (dispatch_time_t)dispatchTimeNow
{
    return dispatch_time(DISPATCH_TIME_NOW, 0);
}

- (NSInteger)timezoneOffset
{
    return [NSTimeZone localTimeZone].secondsFromGMT;
}

- (uint64_t)systemTime
{
    return getAbsoluteTime();
}

@end
