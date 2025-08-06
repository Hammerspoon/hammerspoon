#import "SentryTime.h"

#import <Foundation/Foundation.h>
#import <ctime>
#import <mach/mach_time.h>

#import "SentryAsyncSafeLog.h"
#import "SentryMachLogging.hpp"

uint64_t
timeIntervalToNanoseconds(double seconds)
{
    NSCAssert(seconds >= 0, @"Seconds must be a positive value");
    NSCAssert(seconds <= (double)UINT64_MAX / (double)NSEC_PER_SEC,
        @"Value of seconds is too great; will overflow if casted to a uint64_t");
    return (uint64_t)(seconds * NSEC_PER_SEC);
}

double
nanosecondsToTimeInterval(uint64_t nanoseconds)
{
    return (double)nanoseconds / NSEC_PER_SEC;
}

bool
orderedChronologically(uint64_t a, uint64_t b)
{
    return b >= a;
}

uint64_t
getDurationNs(uint64_t startTimestamp, uint64_t endTimestamp)
{
    NSCAssert(endTimestamp >= startTimestamp, @"Inputs must be chronologically ordered.");
    if (endTimestamp < startTimestamp) {
        return 0;
    }

    uint64_t duration = endTimestamp - startTimestamp;
    if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)) {
        return duration;
    }

    static struct mach_timebase_info info;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(mach_timebase_info(&info)); });
    duration *= info.numer;
    duration /= info.denom;
    return duration;
}
