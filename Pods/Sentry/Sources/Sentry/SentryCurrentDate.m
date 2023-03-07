#import "SentryCurrentDate.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDefaultCurrentDateProvider.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryCurrentDate ()

@end

@implementation SentryCurrentDate

static id<SentryCurrentDateProvider> currentDateProvider;

+ (NSDate *)date
{
    if (currentDateProvider == nil) {
        currentDateProvider = [SentryDefaultCurrentDateProvider sharedInstance];
    }
    return [currentDateProvider date];
}

+ (dispatch_time_t)dispatchTimeNow
{
    if (currentDateProvider == nil) {
        currentDateProvider = [SentryDefaultCurrentDateProvider sharedInstance];
    }
    return [currentDateProvider dispatchTimeNow];
}

+ (void)setCurrentDateProvider:(nullable id<SentryCurrentDateProvider>)value
{
    currentDateProvider = value;
}

+ (nullable id<SentryCurrentDateProvider>)getCurrentDateProvider
{
    return currentDateProvider;
}

@end

NS_ASSUME_NONNULL_END
