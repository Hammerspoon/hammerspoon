#import <SentryWatchdogTerminationTrackingIntegration.h>

#if SENTRY_HAS_UIKIT

#    import "SentryScope+Private.h"
#    import <SentryAppState.h>
#    import <SentryAppStateManager.h>
#    import <SentryClient+Private.h>
#    import <SentryCrashWrapper.h>
#    import <SentryDependencyContainer.h>
#    import <SentryDispatchQueueWrapper.h>
#    import <SentryHub.h>
#    import <SentryOptions+Private.h>
#    import <SentrySDK+Private.h>
#    import <SentryWatchdogTerminationLogic.h>
#    import <SentryWatchdogTerminationScopeObserver.h>
#    import <SentryWatchdogTerminationTracker.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryWatchdogTerminationTrackingIntegration ()

@property (nonatomic, strong) SentryWatchdogTerminationTracker *tracker;
@property (nonatomic, strong) SentryANRTracker *anrTracker;
@property (nullable, nonatomic, copy) NSString *testConfigurationFilePath;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;

@end

@implementation SentryWatchdogTerminationTrackingIntegration

- (instancetype)init
{
    if (self = [super init]) {
        self.testConfigurationFilePath
            = NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"];
    }
    return self;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (self.testConfigurationFilePath) {
        return NO;
    }

    if (![super installWithOptions:options]) {
        return NO;
    }

    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    SentryDispatchQueueWrapper *dispatchQueueWrapper =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-out-of-memory-tracker"
                                              attributes:attributes];

    SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
    SentryAppStateManager *appStateManager =
        [SentryDependencyContainer sharedInstance].appStateManager;
    SentryCrashWrapper *crashWrapper = [SentryDependencyContainer sharedInstance].crashWrapper;
    SentryWatchdogTerminationLogic *logic =
        [[SentryWatchdogTerminationLogic alloc] initWithOptions:options
                                                   crashAdapter:crashWrapper
                                                appStateManager:appStateManager];

    self.tracker = [[SentryWatchdogTerminationTracker alloc] initWithOptions:options
                                                    watchdogTerminationLogic:logic
                                                             appStateManager:appStateManager
                                                        dispatchQueueWrapper:dispatchQueueWrapper
                                                                 fileManager:fileManager];

    [self.tracker start];

    self.anrTracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval];
    [self.anrTracker addListener:self];

    self.appStateManager = appStateManager;

    SentryWatchdogTerminationScopeObserver *scopeObserver =
        [[SentryWatchdogTerminationScopeObserver alloc]
            initWithMaxBreadcrumbs:options.maxBreadcrumbs
                       fileManager:[[[SentrySDK currentHub] getClient] fileManager]];

    [SentrySDK.currentHub configureScope:^(
        SentryScope *_Nonnull outerScope) { [outerScope addObserver:scopeObserver]; }];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableWatchdogTerminationTracking
        | kIntegrationOptionEnableCrashHandler;
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
    [self.anrTracker removeListener:self];
}

- (void)anrDetected
{
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = YES; }];
}

- (void)anrStopped
{
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = NO; }];
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
