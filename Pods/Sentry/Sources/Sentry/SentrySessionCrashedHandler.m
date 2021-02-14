#import "SentrySessionCrashedHandler.h"
#import "SentryClient+Private.h"
#import "SentryClient.h"
#import "SentryCrashAdapter.h"
#import "SentryCurrentDate.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryFileManager.h"
#import "SentryHub.h"
#import "SentrySDK.h"
#import "SentrySession.h"

@interface
SentrySessionCrashedHandler ()

@property (nonatomic, strong) SentryCrashAdapter *crashWrapper;

@end

@implementation SentrySessionCrashedHandler

- (instancetype)initWithCrashWrapper:(SentryCrashAdapter *)crashWrapper
{
    self = [self init];
    self.crashWrapper = crashWrapper;

    return self;
}

- (void)endCurrentSessionAsCrashedWhenCrashed
{
    if (self.crashWrapper.crashedLastLaunch) {
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
