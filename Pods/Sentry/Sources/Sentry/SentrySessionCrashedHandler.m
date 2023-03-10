#import "SentrySessionCrashedHandler.h"
#import "SentryClient+Private.h"
#import "SentryCrashWrapper.h"
#import "SentryCurrentDate.h"
#import "SentryFileManager.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentryWatchdogTerminationLogic.h"

@interface
SentrySessionCrashedHandler ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryWatchdogTerminationLogic *watchdogTerminationLogic;

@end

@implementation SentrySessionCrashedHandler

- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
            watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic;
{
    self = [self init];
    self.crashWrapper = crashWrapper;
    self.watchdogTerminationLogic = watchdogTerminationLogic;

    return self;
}

- (void)endCurrentSessionAsCrashedWhenCrashOrOOM
{
    if (self.crashWrapper.crashedLastLaunch ||
        [self.watchdogTerminationLogic isWatchdogTermination]) {
        SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];

        if (nil == fileManager) {
            return;
        }

        SentrySession *session = [fileManager readCurrentSession];
        if (nil == session) {
            return;
        }

        NSDate *timeSinceLastCrash = [[SentryCurrentDate date]
            dateByAddingTimeInterval:-self.crashWrapper.activeDurationSinceLastCrash];

        [session endSessionCrashedWithTimestamp:timeSinceLastCrash];
        [fileManager storeCrashedSession:session];
        [fileManager deleteCurrentSession];
    }
}

@end
