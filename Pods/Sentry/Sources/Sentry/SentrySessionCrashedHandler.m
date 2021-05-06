#import "SentrySessionCrashedHandler.h"
#import "SentryClient+Private.h"
#import "SentryCrashAdapter.h"
#import "SentryCurrentDate.h"
#import "SentryFileManager.h"
#import "SentryHub.h"
#import "SentryOutOfMemoryLogic.h"
#import "SentrySDK+Private.h"

@interface
SentrySessionCrashedHandler ()

@property (nonatomic, strong) SentryCrashAdapter *crashWrapper;
@property (nonatomic, strong) SentryOutOfMemoryLogic *outOfMemoryLogic;

@end

@implementation SentrySessionCrashedHandler

- (instancetype)initWithCrashWrapper:(SentryCrashAdapter *)crashWrapper
                    outOfMemoryLogic:(SentryOutOfMemoryLogic *)outOfMemoryLogic;
{
    self = [self init];
    self.crashWrapper = crashWrapper;
    self.outOfMemoryLogic = outOfMemoryLogic;

    return self;
}

- (void)endCurrentSessionAsCrashedWhenCrashOrOOM
{
    if (self.crashWrapper.crashedLastLaunch || [self.outOfMemoryLogic isOOM]) {
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
