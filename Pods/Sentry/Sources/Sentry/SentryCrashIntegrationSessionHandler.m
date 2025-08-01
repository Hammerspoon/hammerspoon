#import "SentryCrashIntegrationSessionHandler.h"
#import "SentryClient+Private.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryHub.h"
#import "SentryLogC.h"
#import "SentrySDK+Private.h"
#import "SentrySession.h"
#import "SentrySwift.h"
#import "SentryWatchdogTerminationLogic.h"

@interface SentryCrashIntegrationSessionHandler ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryWatchdogTerminationLogic *watchdogTerminationLogic;
#endif // SENTRY_HAS_UIKIT

@end

@implementation SentryCrashIntegrationSessionHandler

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

- (void)endCurrentSessionIfRequired
{
    SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];

    if (nil == fileManager) {
        SENTRY_LOG_DEBUG(@"File manager is nil. Cannot end current session.");
        return;
    }

    SentrySession *session = [fileManager readCurrentSession];
    if (session == nil) {
        SENTRY_LOG_DEBUG(@"No current session found to end.");
        return;
    }

    if (self.crashWrapper.crashedLastLaunch
#if SENTRY_HAS_UIKIT
        || [self.watchdogTerminationLogic isWatchdogTermination]
#endif // SENTRY_HAS_UIKIT
    ) {
        NSDate *timeSinceLastCrash = [[SentryDependencyContainer.sharedInstance.dateProvider date]
            dateByAddingTimeInterval:-self.crashWrapper.activeDurationSinceLastCrash];

        [session endSessionCrashedWithTimestamp:timeSinceLastCrash];
        [fileManager storeCrashedSession:session];
        [fileManager deleteCurrentSession];
    }
#if SENTRY_HAS_UIKIT
    else {
        // Checking the file existence is way cheaper than reading the file and parsing its contents
        // to an SentryEvent.
        if (![fileManager appHangEventExists]) {
            SENTRY_LOG_DEBUG(@"No app hang event found. Won't end current session.");
            return;
        }

        SentryEvent *appHangEvent = [fileManager readAppHangEvent];
        // Just in case the file was deleted between the check and the read.
        if (appHangEvent == nil) {
            SENTRY_LOG_WARN(
                @"App hang event deleted between check and read. Cannot end current session.");
            return;
        }

        [session endSessionAbnormalWithTimestamp:appHangEvent.timestamp];
        [fileManager storeAbnormalSession:session];
        [fileManager deleteCurrentSession];
    }
#endif // SENTRY_HAS_UIKIT
}

@end
