#import <SentryWatchdogTerminationTrackingIntegration.h>

#if SENTRY_HAS_UIKIT

#    import "SentryScope+Private.h"
#    import <SentryANRTrackerV1.h>
#    import <SentryAppState.h>
#    import <SentryAppStateManager.h>
#    import <SentryClient+Private.h>
#    import <SentryCrashWrapper.h>
#    import <SentryDependencyContainer.h>
#    import <SentryHub.h>
#    import <SentryNSProcessInfoWrapper.h>
#    import <SentryOptions+Private.h>
#    import <SentryPropagationContext.h>
#    import <SentrySDK+Private.h>
#    import <SentrySwift.h>
#    import <SentryWatchdogTerminationBreadcrumbProcessor.h>
#    import <SentryWatchdogTerminationLogic.h>
#    import <SentryWatchdogTerminationScopeObserver.h>
#    import <SentryWatchdogTerminationTracker.h>
NS_ASSUME_NONNULL_BEGIN

@interface SentryWatchdogTerminationTrackingIntegration () <SentryANRTrackerDelegate>

@property (nonatomic, strong) SentryWatchdogTerminationTracker *tracker;
@property (nonatomic, strong) id<SentryANRTracker> anrTracker;
@property (nullable, nonatomic, copy) NSString *testConfigurationFilePath;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;

@end

@implementation SentryWatchdogTerminationTrackingIntegration

- (instancetype)init
{
    if (self = [super init]) {
        SentryNSProcessInfoWrapper *processInfoWrapper
            = SentryDependencyContainer.sharedInstance.processInfoWrapper;
        self.testConfigurationFilePath
            = processInfoWrapper.environment[@"XCTestConfigurationFilePath"];
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
        [[SentryDispatchQueueWrapper alloc] initWithName:"io.sentry.watchdog-termination-tracker"
                                              attributes:attributes];

    SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
    SentryAppStateManager *appStateManager =
        [SentryDependencyContainer sharedInstance].appStateManager;
    SentryCrashWrapper *crashWrapper = [SentryDependencyContainer sharedInstance].crashWrapper;
    SentryWatchdogTerminationLogic *logic =
        [[SentryWatchdogTerminationLogic alloc] initWithOptions:options
                                                   crashAdapter:crashWrapper
                                                appStateManager:appStateManager];
    SentryScopePersistentStore *scopeStore =
        [SentryDependencyContainer.sharedInstance scopePersistentStore];

    self.tracker = [[SentryWatchdogTerminationTracker alloc] initWithOptions:options
                                                    watchdogTerminationLogic:logic
                                                             appStateManager:appStateManager
                                                        dispatchQueueWrapper:dispatchQueueWrapper
                                                                 fileManager:fileManager
                                                        scopePersistentStore:scopeStore];

    [self.tracker start];

    self.anrTracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval
                                                    isV2Enabled:options.enableAppHangTrackingV2];
    [self.anrTracker addListener:self];

    self.appStateManager = appStateManager;

    SentryWatchdogTerminationScopeObserver *scopeObserver =
        [SentryDependencyContainer.sharedInstance
            getWatchdogTerminationScopeObserverWithOptions:options];

    [SentrySDK.currentHub configureScope:^(SentryScope *_Nonnull outerScope) {
        // Add the observer to the scope so that it can be notified when the scope changes.
        [outerScope addObserver:scopeObserver];

        // Sync the current context to the observer to capture context modifications that happened
        // before installation.
        [scopeObserver setContext:outerScope.contextDictionary];
        [scopeObserver setUser:outerScope.userObject];
        [scopeObserver setEnvironment:outerScope.environmentString];
        [scopeObserver setDist:outerScope.distString];
        [scopeObserver setTags:outerScope.tags];
        [scopeObserver setExtras:outerScope.extraDictionary];
        [scopeObserver setFingerprint:outerScope.fingerprintArray];
        // We intentionally skip calling `setTraceContext:` since traces are not stored for watchdog
        // termination events
        // We intentionally skip calling `setLevel:` since all termination events have fatal level
    }];

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

- (void)anrDetectedWithType:(enum SentryANRType)type
{
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = YES; }];
}

- (void)anrStoppedWithResult:(SentryANRStoppedResult *_Nullable)result
{
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = NO; }];
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
