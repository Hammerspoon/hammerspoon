#import "SentryDefines.h"

@class SentryANRTracker;
@class SentryAppStateManager;
@class SentryBinaryImageCache;
@class SentryCrash;
@class SentryCrashWrapper;
@class SentryCurrentDateProvider;
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
@protocol SentryRandom;

#if SENTRY_HAS_METRIC_KIT
@class SentryMXManager;
#endif // SENTRY_HAS_METRIC_KIT

#if SENTRY_UIKIT_AVAILABLE
@class SentryFramesTracker;
@class SentryScreenshot;
@class SentryUIApplication;
@class SentryViewHierarchy;
#endif // SENTRY_UIKIT_AVAILABLE

#if TARGET_OS_IOS
@class SentryUIDeviceWrapper;
#endif // TARGET_OS_IOS

#if !TARGET_OS_WATCH
@class SentryReachability;
#endif // !TARGET_OS_WATCH

NS_ASSUME_NONNULL_BEGIN

@interface SentryDependencyContainer : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

/**
 * Set all dependencies to nil for testing purposes.
 */
+ (void)reset;

@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryCrash *crashReporter;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) id<SentryRandom> random;
@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryNSNotificationCenterWrapper *notificationCenterWrapper;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;
@property (nonatomic, strong) SentryANRTracker *anrTracker;
@property (nonatomic, strong) SentryNSProcessInfoWrapper *processInfoWrapper;
@property (nonatomic, strong) SentrySystemWrapper *systemWrapper;
@property (nonatomic, strong) SentryDispatchFactory *dispatchFactory;
@property (nonatomic, strong) SentryNSTimerFactory *timerFactory;
@property (nonatomic, strong) SentryCurrentDateProvider *dateProvider;
@property (nonatomic, strong) SentryBinaryImageCache *binaryImageCache;
@property (nonatomic, strong) SentryExtraContextProvider *extraContextProvider;
@property (nonatomic, strong) SentrySysctl *sysctlWrapper;
@property (nonatomic, strong) SentryThreadInspector *threadInspector;

#if SENTRY_UIKIT_AVAILABLE
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, strong) SentryScreenshot *screenshot;
@property (nonatomic, strong) SentryViewHierarchy *viewHierarchy;
@property (nonatomic, strong) SentryUIApplication *application;
#endif // SENTRY_UIKIT_AVAILABLE

#if TARGET_OS_IOS
@property (nonatomic, strong) SentryUIDeviceWrapper *uiDeviceWrapper;
#endif // TARGET_OS_IOS

#if !TARGET_OS_WATCH
@property (nonatomic, strong) SentryReachability *reachability;
#endif // !TARGET_OS_WATCH

- (SentryANRTracker *)getANRTracker:(NSTimeInterval)timeout;

#if SENTRY_HAS_METRIC_KIT
@property (nonatomic, strong) SentryMXManager *metricKitManager API_AVAILABLE(
    ios(15.0), macos(12.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);
#endif

@end

NS_ASSUME_NONNULL_END
