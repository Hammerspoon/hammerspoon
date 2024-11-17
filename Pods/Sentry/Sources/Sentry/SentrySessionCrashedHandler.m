#import "SentrySessionCrashedHandler.h"
#import "SentryClient+Private.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentrySession.h"
#import "SentrySwift.h"
#import "SentryWatchdogTerminationLogic.h"

@interface
SentrySessionCrashedHandler ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryWatchdogTerminationLogic *watchdogTerminationLogic;
#endif // SENTRY_HAS_UIKIT

@end

@implementation SentrySessionCrashedHandler

#if SENTRY_HAS_UIKIT
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
            watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic
#else
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
#endif // SENTRY_HAS_UIKIT
{
    self = [self init];
    self.crashWrapper = crashWrapper;
#if SENTRY_HAS_UIKIT
    self.watchdogTerminationLogic = watchdogTerminationLogic;
#endif // SENTRY_HAS_UIKIT

    return self;
}

- (void)endCurrentSessionAsCrashedWhenCrashOrOOM
{
    if (self.crashWrapper.crashedLastLaunch
#if SENTRY_HAS_UIKIT
        || [self.watchdogTerminationLogic isWatchdogTermination]
#endif // SENTRY_HAS_UIKIT
    ) {
        SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];

        if (nil == fileManager) {
            return;
        }

        SentrySession *session = [fileManager readCurrentSession];
        if (nil == session) {
            return;
        }

        NSDate *timeSinceLastCrash = [[SentryDependencyContainer.sharedInstance.dateProvider date]
            dateByAddingTimeInterval:-self.crashWrapper.activeDurationSinceLastCrash];

        [session endSessionCrashedWithTimestamp:timeSinceLastCrash];
        [fileManager storeCrashedSession:session];
        [fileManager deleteCurrentSession];
    }
}

@end
