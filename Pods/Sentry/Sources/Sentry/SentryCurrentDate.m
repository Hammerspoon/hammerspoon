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
    if (nil == currentDateProvider) {
        currentDateProvider = [SentryDefaultCurrentDateProvider sharedInstance];
    }
    return [currentDateProvider date];
}

+ (void)setCurrentDateProvider:(nullable id<SentryCurrentDateProvider>)value
{
    currentDateProvider = value;
}

@end

NS_ASSUME_NONNULL_END
