#import "SentryAppStartTrackingIntegration.h"
#import "SentryAppStartTracker.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryLog.h"
#import <Foundation/Foundation.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashAdapter.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryHub.h>
#import <SentrySDK+Private.h>
#import <SentrySysctl.h>

@interface
SentryAppStartTrackingIntegration ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryAppStartTracker *tracker;
#endif

@end

@implementation SentryAppStartTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
#if SENTRY_HAS_UIKIT
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog
            logWithMessage:@"AutoUIPerformanceTracking disabled. Will not track app start up time."
                  andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.isTracingEnabled) {
        [SentryLog
            logWithMessage:
                @"No tracesSampleRate and tracesSampler set. Will not track app start up time."
                  andLevel:kSentryLevelDebug];
        return;
    }

    SentryDefaultCurrentDateProvider *currentDateProvider =
        [SentryDefaultCurrentDateProvider sharedInstance];
    SentryCrashAdapter *crashAdapter = [SentryCrashAdapter sharedInstance];
    SentrySysctl *sysctl = [[SentrySysctl alloc] init];

    SentryAppStateManager *appStateManager = [[SentryAppStateManager alloc]
            initWithOptions:options
               crashAdapter:crashAdapter
                fileManager:[[[SentrySDK currentHub] getClient] fileManager]
        currentDateProvider:currentDateProvider
                     sysctl:sysctl];

    self.tracker = [[SentryAppStartTracker alloc]
        initWithCurrentDateProvider:currentDateProvider
               dispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]
                    appStateManager:appStateManager
                             sysctl:sysctl];
    [self.tracker start];

#else
    [SentryLog logWithMessage:@"NO UIKit -> SentryAppStartTracker will not track app start up time."
                     andLevel:kSentryLevelDebug];
#endif
}

- (void)uninstall
{
    [self stop];
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    if (nil != self.tracker) {
        [self.tracker stop];
    }
#endif
}

@end
