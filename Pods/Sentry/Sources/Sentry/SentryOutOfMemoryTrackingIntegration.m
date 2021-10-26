#import <Foundation/Foundation.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashAdapter.h>
#import <SentryDefaultCurrentDateProvider.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryHub.h>
#import <SentryOutOfMemoryLogic.h>
#import <SentryOutOfMemoryTracker.h>
#import <SentryOutOfMemoryTrackingIntegration.h>
#import <SentrySDK+Private.h>
#import <SentrySysctl.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryOutOfMemoryTrackingIntegration ()

@property (nonatomic, strong) SentryOutOfMemoryTracker *tracker;

@end

@implementation SentryOutOfMemoryTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (options.enableOutOfMemoryTracking) {
        dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        SentryDispatchQueueWrapper *dispatchQueueWrapper =
            [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-out-of-memory-tracker"
                                                  attributes:attributes];

        SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
        SentryCrashAdapter *crashAdapter = [SentryCrashAdapter sharedInstance];
        SentryAppStateManager *appStateManager = [[SentryAppStateManager alloc]
                initWithOptions:options
                   crashAdapter:crashAdapter
                    fileManager:fileManager
            currentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                         sysctl:[[SentrySysctl alloc] init]];
        SentryOutOfMemoryLogic *logic =
            [[SentryOutOfMemoryLogic alloc] initWithOptions:options
                                               crashAdapter:crashAdapter
                                            appStateManager:appStateManager];

        self.tracker = [[SentryOutOfMemoryTracker alloc] initWithOptions:options
                                                        outOfMemoryLogic:logic
                                                         appStateManager:appStateManager
                                                    dispatchQueueWrapper:dispatchQueueWrapper
                                                             fileManager:fileManager];
        [self.tracker start];
    }
}

- (void)uninstall
{
    [self stop];
}

- (void)stop
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

@end

NS_ASSUME_NONNULL_END
