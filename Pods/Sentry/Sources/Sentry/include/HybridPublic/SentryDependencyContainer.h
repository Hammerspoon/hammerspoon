#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

@class SentryAppStateManager;
@class SentryBinaryImageCache;
@class SentryCrash;
@class SentryCrashWrapper;
@class SentryDebugImageProvider;
@class SentryDispatchFactory;
@class SentryDispatchQueueWrapper;
@class SentryExtraContextProvider;
@class SentryFileManager;
@class SentryNSNotificationCenterWrapper;
@class SentryNSProcessInfoWrapper;
@class SentryNSTimerFactory;
@class SentrySwizzleWrapper;
@class SentrySysctl;
@class SentrySystemWrapper;
@class SentryThreadWrapper;
@class SentryThreadInspector;
@class SentryFileIOTracker;
@class SentryScopePersistentStore;
@class SentryOptions;
@class SentrySessionTracker;
@class SentryGlobalEventProcessor;

@protocol SentryANRTracker;
@protocol SentryRandom;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;
@protocol SentryApplication;
@protocol SentryDispatchQueueProviderProtocol;

#if SENTRY_HAS_METRIC_KIT
@class SentryMXManager;
#endif // SENTRY_HAS_METRIC_KIT

#if SENTRY_UIKIT_AVAILABLE
@class SentryFramesTracker;
@class SentryScreenshot;
@class SentryUIApplication;
@class SentryViewHierarchyProvider;
@class SentryUIViewControllerPerformanceTracker;
@class SentryWatchdogTerminationScopeObserver;
@class SentryWatchdogTerminationAttributesProcessor;
@class SentryWatchdogTerminationBreadcrumbProcessor;
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_HAS_UIKIT
@class SentryUIDeviceWrapper;
#endif // TARGET_OS_IOS

#if !TARGET_OS_WATCH
@class SentryReachability;
#endif // !TARGET_OS_WATCH

NS_ASSUME_NONNULL_BEGIN

/**
 * The dependency container is optimized to use as few locks as possible and to only keep the
 * required dependencies in memory. It splits its dependencies into two groups.
 *
 * Init Dependencies: These are mandatory dependencies required to run the SDK, no matter the
 * options. The dependency container initializes them in init and uses no locks for efficiency.
 *
 * Lazy Dependencies: These dependencies either have some state or aren't always required and,
 * therefore, get initialized lazily to minimize the memory footprint.
 */
@interface SentryDependencyContainer : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

/**
 * Resets all dependencies.
 */
+ (void)reset;

#pragma mark - Init Dependencies

@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) id<SentryRandom> random;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) SentryBinaryImageCache *binaryImageCache;
@property (nonatomic, strong) id<SentryCurrentDateProvider> dateProvider;
@property (nonatomic, strong) SentryExtraContextProvider *extraContextProvider;
@property (nonatomic, strong) SentryNSNotificationCenterWrapper *notificationCenterWrapper;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryNSProcessInfoWrapper *processInfoWrapper;
@property (nonatomic, strong) SentrySysctl *sysctlWrapper;
@property (nonatomic, strong) id<SentryRateLimits> rateLimits;
@property (nonatomic, strong) id<SentryApplication> application;

#if SENTRY_HAS_REACHABILITY
@property (nonatomic, strong) SentryReachability *reachability;
#endif // !TARGET_OS_WATCH

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryUIDeviceWrapper *uiDeviceWrapper;
#endif // TARGET_OS_IOS

#pragma mark - Lazy Dependencies

@property (nonatomic, strong, nullable) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryThreadInspector *threadInspector;
@property (nonatomic, strong) SentryFileIOTracker *fileIOTracker;
@property (nonatomic, strong) SentryCrash *crashReporter;
@property (nonatomic, strong) SentryScopePersistentStore *scopePersistentStore;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;

- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout;
#if SENTRY_HAS_UIKIT
- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout isV2Enabled:(BOOL)isV2Enabled;
#endif // SENTRY_HAS_UIKIT

@property (nonatomic, strong) SentrySystemWrapper *systemWrapper;
@property (nonatomic, strong) SentryDispatchFactory *dispatchFactory;
@property (nonatomic, strong) id<SentryDispatchQueueProviderProtocol> dispatchQueueProvider;
@property (nonatomic, strong) SentryNSTimerFactory *timerFactory;

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
#if SENTRY_UIKIT_AVAILABLE
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, strong) SentryScreenshot *screenshot;
@property (nonatomic, strong) SentryViewHierarchyProvider *viewHierarchyProvider;
@property (nonatomic, strong)
    SentryUIViewControllerPerformanceTracker *uiViewControllerPerformanceTracker;
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_HAS_METRIC_KIT
@property (nonatomic, strong) SentryMXManager *metricKitManager API_AVAILABLE(
    ios(15.0), macos(12.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);
#endif // SENTRY_HAS_METRIC_KIT

#if SENTRY_HAS_UIKIT
- (SentryWatchdogTerminationScopeObserver *)getWatchdogTerminationScopeObserverWithOptions:
    (SentryOptions *)options;
- (SentryWatchdogTerminationBreadcrumbProcessor *)
    getWatchdogTerminationBreadcrumbProcessorWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;
@property (nonatomic, strong)
    SentryWatchdogTerminationAttributesProcessor *watchdogTerminationAttributesProcessor;
#endif

@property (nonatomic, strong) SentryGlobalEventProcessor *globalEventProcessor;
- (SentrySessionTracker *)getSessionTrackerWithOptions:(SentryOptions *)options;

@end

NS_ASSUME_NONNULL_END
