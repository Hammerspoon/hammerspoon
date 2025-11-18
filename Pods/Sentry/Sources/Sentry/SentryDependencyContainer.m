#import "SentryANRTrackerV1.h"

#import "SentryDispatchFactory.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryExtraContextProvider.h"
#import "SentryFileIOTracker.h"
#import "SentryFileManager.h"
#import "SentryInternalCDefines.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySessionTracker.h"
#import "SentrySwift.h"
#import "SentrySystemWrapper.h"
#import "SentryThreadInspector.h"
#import <SentryAppStateManager.h>
#import <SentryCrash.h>
#import <SentryDebugImageProvider+HybridSDKs.h>
#import <SentryDefaultRateLimits.h>
#import <SentryDependencyContainer.h>
#import <SentryHttpDateParser.h>
#import <SentryPerformanceTracker.h>
#import <SentryRateLimitParser.h>
#import <SentryRetryAfterHeaderParser.h>
#import <SentrySDK+Private.h>
#import <SentrySwift.h>
#import <SentrySwizzleWrapper.h>
#import <SentryTracer.h>
#import <SentryUIViewControllerPerformanceTracker.h>
#import <SentryWatchdogTerminationScopeObserver.h>

#if SENTRY_HAS_UIKIT
#    import "SentryANRTrackerV2.h"
#    import "SentryFramesTracker.h"
#    import <SentryWatchdogTerminationBreadcrumbProcessor.h>
#endif // SENTRY_HAS_UIKIT

#if !TARGET_OS_WATCH
#    import "SentryReachability.h"
#endif // !TARGET_OS_WATCH

/**
 * Macro for implementing lazy initialization with a double-checked lock. The double-checked lock
 * speeds up the dependency retrieval by around 5%, so it's worth having it. Measured with
 * self.measure in unit tests.
 */
#define SENTRY_LAZY_INIT(instance, initBlock)                                                      \
    if (instance == nil) {                                                                         \
        @synchronized(sentryDependencyContainerDependenciesLock) {                                 \
            if (instance == nil) {                                                                 \
                instance = initBlock;                                                              \
            }                                                                                      \
        }                                                                                          \
    }                                                                                              \
    return instance;

#define SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK                                                \
    SENTRY_DISABLE_THREAD_SANITIZER("Double-checked locks produce false alarms.")

typedef id<SentryApplication> _Nullable (^SentryApplicationProviderBlock)(void);
// Declare the application provider block at the top level to prevent capturing 'self'
// from the dependency container, which would create cyclic dependencies and memory leaks.
SentryApplicationProviderBlock defaultApplicationProvider = ^id<SentryApplication> _Nullable()
{
#if SENTRY_HAS_UIKIT
    return UIApplication.sharedApplication;
#elif TARGET_OS_OSX
    return NSApplication.sharedApplication;
#endif
    return nil;
};

@interface SentryFileManager () <SentryFileManagerProtocol>
@end

@interface SentryDependencyContainer ()

@property (nonatomic, strong) id<SentryANRTracker> anrTracker;

@end

@implementation SentryDependencyContainer

static SentryDependencyContainer *instance;
static NSObject *sentryDependencyContainerDependenciesLock;
static NSObject *sentryDependencyContainerInstanceLock;
static BOOL isInitialializingDependencyContainer = NO;

+ (void)initialize
{
    if (self == [SentryDependencyContainer class]) {
        // We use two locks, because we don't want the dependencies to block the instance lock.
        // Using two locks speeds up the accessing the dependencies around 5%, which is worth having
        // the extra lock. Measured with self.measure in unit tests.
        sentryDependencyContainerInstanceLock = [[NSObject alloc] init];
        sentryDependencyContainerDependenciesLock = [[NSObject alloc] init];

        instance = [[SentryDependencyContainer alloc] init];
    }
}

+ (instancetype)sharedInstance
{
    // This synchronization adds around 5% slowdown compared to no synchronization.
    // As we don't call this method in a tight loop, it's acceptable. Measured with self.measure in
    // unit tests.
    @synchronized(sentryDependencyContainerInstanceLock) {

        if (isInitialializingDependencyContainer) {
            SENTRY_GRACEFUL_FATAL(
                @"SentryDependencyContainer is currently being initialized, so your requested "
                @"dependency via sharedInstance will be nil. You MUST NOT call sharedInstance in "
                @"your initializer. Instead, pass the dependency you're trying to get via the "
                @"constructor. If the stacktrace doesn't point to the root cause, the easiest way "
                @"to identify the root caus is to set a breakpoint exactly here and then check the "
                @"stacktrace.");
        }

        return instance;
    }
}

+ (void)reset
{
    @synchronized(sentryDependencyContainerInstanceLock) {
#if SENTRY_HAS_REACHABILITY
        [instance->_reachability removeAllObservers];
#endif // !TARGET_OS_WATCH

#if SENTRY_HAS_UIKIT
        [instance->_framesTracker stop];
#endif // SENTRY_HAS_UIKIT

        // We create a new instance to reset all dependencies to a fresh state.
        // Why don't we reset all dependencies manually so we can avoid using a lock in
        // sharedInstance? Good question. This approach comes with the following problems:
        //
        // 1. We need a lock for all properties, including the init dependencies.
        //
        // 2. When adding a new dependency it is very easy to forget adding it to the reset list
        //
        // 3. The lock in sharedInstance only caused around a 5% overhead compared to not using a
        // lock. Measured with self.measure in unit tests. So not having locks for all the init
        // dependencies is as efficient as having a lock for the instance in sharedInstance.
        instance = [[SentryDependencyContainer alloc] init];
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        isInitialializingDependencyContainer = YES;

        _dispatchQueueWrapper = SentryDependencies.dispatchQueueWrapper;
        _random = [[SentryRandom alloc] init];
        _threadWrapper = [[SentryThreadWrapper alloc] init];
        _binaryImageCache = [[SentryBinaryImageCache alloc] init];
        _dateProvider = SentryDependencies.dateProvider;

        _notificationCenterWrapper = NSNotificationCenter.defaultCenter;

        _processInfoWrapper = NSProcessInfo.processInfo;
        _crashWrapper = [[SentryCrashWrapper alloc] initWithProcessInfoWrapper:_processInfoWrapper];
#if SENTRY_HAS_UIKIT
        _uiDeviceWrapper = SentryDependencies.uiDeviceWrapper;
        _threadsafeApplication = [[SentryThreadsafeApplication alloc]
            initWithApplicationProvider:defaultApplicationProvider
                     notificationCenter:_notificationCenterWrapper];
#endif // SENTRY_HAS_UIKIT

        _extraContextProvider =
            [[SentryExtraContextProvider alloc] initWithCrashWrapper:_crashWrapper
                                                  processInfoWrapper:_processInfoWrapper
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
                                                       deviceWrapper:_uiDeviceWrapper
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
        ];

        _sysctlWrapper = [[SentrySysctl alloc] init];

        SentryRetryAfterHeaderParser *retryAfterHeaderParser = [[SentryRetryAfterHeaderParser alloc]
            initWithHttpDateParser:[[SentryHttpDateParser alloc] init]
               currentDateProvider:_dateProvider];
        SentryRateLimitParser *rateLimitParser =
            [[SentryRateLimitParser alloc] initWithCurrentDateProvider:_dateProvider];

        _rateLimits =
            [[SentryDefaultRateLimits alloc] initWithRetryAfterHeaderParser:retryAfterHeaderParser
                                                         andRateLimitParser:rateLimitParser
                                                        currentDateProvider:_dateProvider];
        _infoPlistWrapper = [[SentryInfoPlistWrapper alloc] init];
        _sessionReplayEnvironmentChecker = [[SentrySessionReplayEnvironmentChecker alloc]
            initWithInfoPlistWrapper:_infoPlistWrapper];

#if SENTRY_HAS_REACHABILITY
        _reachability = [[SentryReachability alloc] init];
#endif // !SENTRY_HAS_REACHABILITY

        isInitialializingDependencyContainer = NO;
    }
    return self;
}

- (nullable id<SentryApplication>)application
{
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    id<SentryApplication> override = self.applicationOverride;
    if (override) {
        return override;
    }
#endif
    return defaultApplicationProvider();
}

- (nullable SentryFileManager *)fileManager SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_fileManager, ({
        NSError *error;
        SentryFileManager *manager =
            [[SentryFileManager alloc] initWithOptions:SentrySDKInternal.options
                                          dateProvider:self.dateProvider
                                  dispatchQueueWrapper:self.dispatchQueueWrapper
                                                 error:&error];
        if (manager == nil) {
            SENTRY_LOG_DEBUG(@"Could not create file manager - %@", error);
        }
        manager;
    }));
}

- (SentryAppStateManager *)appStateManager SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_appStateManager,
        [[SentryAppStateManager alloc] initWithOptions:SentrySDKInternal.options
                                          crashWrapper:self.crashWrapper
                                           fileManager:self.fileManager
                                  dispatchQueueWrapper:self.dispatchQueueWrapper
                             notificationCenterWrapper:self.notificationCenterWrapper]);
}

- (SentryThreadInspector *)threadInspector SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_threadInspector,
        [[SentryThreadInspector alloc] initWithOptions:SentrySDKInternal.options]);
}

- (SentryFileIOTracker *)fileIOTracker SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_fileIOTracker,
        [[SentryFileIOTracker alloc] initWithThreadInspector:[self threadInspector]
                                          processInfoWrapper:[self processInfoWrapper]]);
}

- (SentryCrash *)crashReporter SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_crashReporter,
        [[SentryCrash alloc] initWithBasePath:SentrySDKInternal.options.cacheDirectoryPath]);
}

- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout
    SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_anrTracker,
        [[[SentryANRTrackerV1 alloc] initWithTimeoutInterval:timeout
                                                crashWrapper:self.crashWrapper
                                        dispatchQueueWrapper:self.dispatchQueueWrapper
                                               threadWrapper:self.threadWrapper] asProtocol]);
}

#if SENTRY_HAS_UIKIT
- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout
                          isV2Enabled:(BOOL)isV2Enabled SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    if (isV2Enabled) {
        SENTRY_LAZY_INIT(_anrTracker,
            [[[SentryANRTrackerV2 alloc] initWithTimeoutInterval:timeout
                                                    crashWrapper:self.crashWrapper
                                            dispatchQueueWrapper:self.dispatchQueueWrapper
                                                   threadWrapper:self.threadWrapper
                                                   framesTracker:self.framesTracker] asProtocol]);
    } else {
        return [self getANRTracker:timeout];
    }
}
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_REPLAY_SUPPORTED
- (nonnull SentryScreenshotSource *)screenshotSource SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    @synchronized(sentryDependencyContainerDependenciesLock) {
        if (_screenshotSource == nil) {
            // The options could be null here, but this is a general issue in the dependency
            // container and will be fixed in a future refactoring.
            SentryViewScreenshotOptions *_Nonnull options = SENTRY_UNWRAP_NULLABLE(
                SentryViewScreenshotOptions, SentrySDKInternal.options.screenshot);

            id<SentryViewRenderer> viewRenderer;
            if (options.enableViewRendererV2) {
                viewRenderer = [[SentryViewRendererV2 alloc]
                    initWithEnableFastViewRendering:options.enableFastViewRendering];
            } else {
                viewRenderer = [[SentryDefaultViewRenderer alloc] init];
            }

            SentryViewPhotographer *photographer =
                [[SentryViewPhotographer alloc] initWithRenderer:viewRenderer
                                                   redactOptions:options
                                            enableMaskRendererV2:options.enableViewRendererV2];
            _screenshotSource = [[SentryScreenshotSource alloc] initWithPhotographer:photographer];
        }

        return _screenshotSource;
    }
}
#endif // SENTRY_HAS_UIKIT

#if SENTRY_UIKIT_AVAILABLE
- (SentryViewHierarchyProvider *)viewHierarchyProvider SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
#    if SENTRY_HAS_UIKIT

    SENTRY_LAZY_INIT(_viewHierarchyProvider,
        [[SentryViewHierarchyProvider alloc]
            initWithDispatchQueueWrapper:self.dispatchQueueWrapper
                     applicationProvider:defaultApplicationProvider]);
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.viewHierarchyProvider only works with UIKit "
        @"enabled. Ensure you're using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryUIViewControllerPerformanceTracker *)
    uiViewControllerPerformanceTracker SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
#    if SENTRY_HAS_UIKIT
    SENTRY_LAZY_INIT(_uiViewControllerPerformanceTracker,
        [[SentryUIViewControllerPerformanceTracker alloc]
                 initWithTracker:SentryPerformanceTracker.shared
            dispatchQueueWrapper:[self dispatchQueueWrapper]]);
#    else
    SENTRY_LOG_DEBUG(@"SentryDependencyContainer.uiViewControllerPerformanceTracker only works "
                     @"with UIKit enabled. Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryFramesTracker *)framesTracker SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
#    if SENTRY_HAS_UIKIT
    SENTRY_LAZY_INIT(_framesTracker,
        [[SentryFramesTracker alloc]
            initWithDisplayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]
                          dateProvider:self.dateProvider
                  dispatchQueueWrapper:self.dispatchQueueWrapper
                    notificationCenter:self.notificationCenterWrapper
             keepDelayedFramesDuration:SENTRY_AUTO_TRANSACTION_MAX_DURATION]);

#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.framesTracker only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentrySwizzleWrapper *)swizzleWrapper SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
#    if SENTRY_HAS_UIKIT
    SENTRY_LAZY_INIT(_swizzleWrapper, [[SentrySwizzleWrapper alloc] init]);
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.swizzleWrapper only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (SentrySystemWrapper *)systemWrapper SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_systemWrapper,
        [[SentrySystemWrapper alloc]
            initWithProcessorCount:self.processInfoWrapper.processorCount]);
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (SentryDispatchFactory *)dispatchFactory SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_dispatchFactory, [[SentryDispatchFactory alloc] init]);
}

- (SentryNSTimerFactory *)timerFactory SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_timerFactory, [[SentryNSTimerFactory alloc] init]);
}

#if SENTRY_HAS_METRIC_KIT
- (SentryMXManager *)metricKitManager SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    // Disable crash diagnostics as we only use it for validation of the symbolication
    // of stacktraces, because crashes are easy to trigger for MetricKit. We don't want
    // crash reports of MetricKit in production as we have SentryCrash.
    SENTRY_LAZY_INIT(
        _metricKitManager, [[SentryMXManager alloc] initWithDisableCrashDiagnostics:YES]);
}

#endif // SENTRY_HAS_METRIC_KIT

- (SentryScopePersistentStore *)scopePersistentStore SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_scopePersistentStore,
        [[SentryScopePersistentStore alloc] initWithFileManager:self.fileManager]);
}

- (SentryDebugImageProvider *)debugImageProvider SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    // SentryDebugImageProvider is public, so we can't initialize the dependency in
    // SentryDependencyInitialize because the SentryDebugImageProvider.init uses the
    // SentryDependencyContainer, which doesn't work because of a chicken egg problem. For more
    // information check SentryDebugImageProvider.sharedInstance.
    SENTRY_LAZY_INIT(_debugImageProvider, [[SentryDebugImageProvider alloc] init]);
}

#if SENTRY_HAS_UIKIT
- (SentryWatchdogTerminationScopeObserver *)getWatchdogTerminationScopeObserverWithOptions:
    (SentryOptions *)options
{
    // This method is only a factory, therefore do not keep a reference.
    // The scope observer will be created each time it is needed.
    return [[SentryWatchdogTerminationScopeObserver alloc]
        initWithBreadcrumbProcessor:
            [self
                getWatchdogTerminationBreadcrumbProcessorWithMaxBreadcrumbs:options.maxBreadcrumbs]
                attributesProcessor:self.watchdogTerminationAttributesProcessor];
}

- (SentryWatchdogTerminationBreadcrumbProcessor *)
    getWatchdogTerminationBreadcrumbProcessorWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
{
    // This method is only a factory, therefore do not keep a reference.
    // The processor will be created each time it is needed.
    return [[SentryWatchdogTerminationBreadcrumbProcessor alloc]
        initWithMaxBreadcrumbs:maxBreadcrumbs
                   fileManager:self.fileManager];
}

- (SentryWatchdogTerminationAttributesProcessor *)
    watchdogTerminationAttributesProcessor SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_watchdogTerminationAttributesProcessor,
        [[SentryWatchdogTerminationAttributesProcessor alloc]
            initWithDispatchQueueWrapper:
                [self.dispatchFactory
                    createUtilityQueue:"io.sentry.watchdog-termination-tracking.fields-processor"
                      relativePriority:0]
                    scopePersistentStore:self.scopePersistentStore])
}
#endif

- (SentryGlobalEventProcessor *)globalEventProcessor SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_globalEventProcessor, [[SentryGlobalEventProcessor alloc] init])
}

- (SentrySessionTracker *)getSessionTrackerWithOptions:(SentryOptions *)options
{
    return [[SentrySessionTracker alloc] initWithOptions:options
                                     applicationProvider:defaultApplicationProvider
                                            dateProvider:self.dateProvider
                                      notificationCenter:self.notificationCenterWrapper];
}

- (id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper SENTRY_THREAD_SANITIZER_DOUBLE_CHECKED_LOCK
{
    SENTRY_LAZY_INIT(_objcRuntimeWrapper, [[SentryDefaultObjCRuntimeWrapper alloc] init]);
}
@end
