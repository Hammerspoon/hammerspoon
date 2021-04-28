#import "SentryCrashAdapter.h"
#import "SentryCrash.h"
#import <Foundation/Foundation.h>
#import <SentryCrashDebug.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryCrashAdapter

- (BOOL)crashedLastLaunch
{
    return SentryCrash.sharedInstance.crashedLastLaunch;
}

- (NSTimeInterval)activeDurationSinceLastCrash
{
    return SentryCrash.sharedInstance.activeDurationSinceLastCrash;
}

- (BOOL)isBeingTraced
{
    return sentrycrashdebug_isBeingTraced();
}

@end

NS_ASSUME_NONNULL_END
