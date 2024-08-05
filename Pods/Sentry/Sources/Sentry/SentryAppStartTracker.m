#import <SentryAppStartTracker.h>

#if SENTRY_HAS_UIKIT

#    import "SentryAppStartMeasurement.h"
#    import "SentryAppStateManager.h"
#    import "SentryDefines.h"
#    import "SentryFramesTracker.h"
#    import "SentryLog.h"
#    import "SentrySysctl.h"
#    import <Foundation/Foundation.h>
#    import <PrivateSentrySDKOnly.h>
#    import <SentryAppState.h>
#    import <SentryDependencyContainer.h>
#    import <SentryDispatchQueueWrapper.h>
#    import <SentryInternalNotificationNames.h>
#    import <SentryLog.h>
#    import <SentrySDK+Private.h>
#    import <SentrySwift.h>
#    import <UIKit/UIKit.h>

static NSDate *runtimeInit = nil;
static BOOL isActivePrewarm = NO;

/**
 * The watchdog usually kicks in after an app hanging for 30 seconds. As the app could hang in
 * multiple stages during the launch we pick a higher threshold.
 */
static const NSTimeInterval SENTRY_APP_START_MAX_DURATION = 180.0;

@interface
SentryAppStartTracker () <SentryFramesTrackerListener>

@property (nonatomic, strong) SentryAppState *previousAppState;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, assign) BOOL wasInBackground;
@property (nonatomic, strong) NSDate *didFinishLaunchingTimestamp;
@property (nonatomic, assign) BOOL enablePreWarmedAppStartTracing;
@property (nonatomic, assign) BOOL enablePerformanceV2;

@end

@implementation SentryAppStartTracker

+ (void)load
{
    // Invoked whenever this class is added to the Objective-C runtime.
    runtimeInit = [NSDate date];

    // The OS sets this environment variable if the app start is pre warmed. There are no official
    // docs for this. Found at https://eisel.me/startup. Investigations show that this variable is
    // deleted after UIApplicationDidFinishLaunchingNotification, so we have to check it here.
    isActivePrewarm =
        [[NSProcessInfo processInfo].environment[@"ActivePrewarm"] isEqualToString:@"1"];
}

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                             appStateManager:(SentryAppStateManager *)appStateManager
                               framesTracker:(SentryFramesTracker *)framesTracker
              enablePreWarmedAppStartTracing:(BOOL)enablePreWarmedAppStartTracing
                         enablePerformanceV2:(BOOL)enablePerformanceV2
{
    if (self = [super init]) {
        self.dispatchQueue = dispatchQueueWrapper;
        self.appStateManager = appStateManager;
        _enablePerformanceV2 = enablePerformanceV2;
        if (_enablePerformanceV2) {
            self.framesTracker = framesTracker;
            [framesTracker addListener:self];
        }

        self.previousAppState = [self.appStateManager loadPreviousAppState];
        self.wasInBackground = NO;
        self.didFinishLaunchingTimestamp =
            [SentryDependencyContainer.sharedInstance.dateProvider date];
        self.enablePreWarmedAppStartTracing = enablePreWarmedAppStartTracing;
        self.isRunning = NO;
    }
    return self;
}

- (BOOL)isActivePrewarmAvailable
{
#    if TARGET_OS_IOS
    // Customer data suggest that app starts are also prewarmed on iOS 14 although this contradicts
    // with Apple docs.
    if (@available(iOS 14, *)) {
        return YES;
    } else {
        return NO;
    }
#    else // !TARGET_OS_IOS
    return NO;
#    endif // TARGET_OS_IOS
}

- (void)start
{
    // It can happen that the OS posts the didFinishLaunching notification before we register for it
    // or we just don't receive it. In this case the didFinishLaunchingTimestamp would be nil. As
    // the SDK should be initialized in application:didFinishLaunchingWithOptions: or in the init of
    // @main of a SwiftUI  we set the timestamp here.
    self.didFinishLaunchingTimestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didFinishLaunching)
                                               name:UIApplicationDidFinishLaunchingNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeVisible)
                                               name:UIWindowDidBecomeVisibleNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];

    if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
        [self
            buildAppStartMeasurement:[SentryDependencyContainer.sharedInstance.dateProvider date]];
    }

#    if SENTRY_HAS_UIKIT
    [self.appStateManager start];
#    endif // SENTRY_HAS_UIKIT

    self.isRunning = YES;
}

- (void)buildAppStartMeasurement:(NSDate *)appStartEnd
{
    void (^block)(void) = ^(void) {
        [self stop];

        BOOL isPreWarmed = NO;
        if ([self isActivePrewarmAvailable] && isActivePrewarm) {
            SENTRY_LOG_INFO(@"The app was prewarmed.");

            if (self.enablePreWarmedAppStartTracing) {
                isPreWarmed = YES;
            } else {
                SENTRY_LOG_INFO(
                    @"EnablePreWarmedAppStartTracing disabled. Not measuring app start.");
                return;
            }
        }

        SentryAppStartType appStartType = [self getStartType];

        if (appStartType == SentryAppStartTypeUnknown) {
            SENTRY_LOG_WARN(@"Unknown start type. Not measuring app start.");
            return;
        }

        if (self.wasInBackground) {
            // If the app was already running in the background it's not a cold or warm
            // start.
            SENTRY_LOG_INFO(@"App was in background. Not measuring app start.");
            return;
        }

        // According to a talk at WWDC about optimizing app launch
        // (https://devstreaming-cdn.apple.com/videos/wwdc/2019/423lzf3qsjedrzivc7/423/423_optimizing_app_launch.pdf?dl=1
        // slide 17) no process exists for cold and warm launches. Since iOS 15, though, the system
        // might decide to pre-warm your app before the user tries to open it.
        // Prewarming can stop at any of the app launch steps. Our findings show that most of
        // the prewarmed app starts don't call the main method. Therefore we subtract the
        // time before the module initialization / main method to calculate the app start
        // duration. If the app start stopped during a later launch step, we drop it below with
        // checking the SENTRY_APP_START_MAX_DURATION. With this approach, we will
        // lose some warm app starts, but we accept this tradeoff. Useful resources:
        // https://developer.apple.com/documentation/uikit/app_and_environment/responding_to_the_launch_of_your_app/about_the_app_launch_sequence#3894431
        // https://developer.apple.com/documentation/metrickit/mxapplaunchmetric,
        // https://twitter.com/steipete/status/1466013492180312068,
        // https://github.com/MobileNativeFoundation/discussions/discussions/146
        // https://eisel.me/startup
        NSTimeInterval appStartDuration = 0.0;
        NSDate *appStartTimestamp;
        SentrySysctl *sysctl = SentryDependencyContainer.sharedInstance.sysctlWrapper;
        if (isPreWarmed) {
            appStartDuration =
                [appStartEnd timeIntervalSinceDate:sysctl.moduleInitializationTimestamp];
            appStartTimestamp = sysctl.moduleInitializationTimestamp;
        } else {
            appStartDuration = [appStartEnd timeIntervalSinceDate:sysctl.processStartTimestamp];
            appStartTimestamp = sysctl.processStartTimestamp;
        }

        // Safety check to not report app starts that are completely off.
        if (appStartDuration >= SENTRY_APP_START_MAX_DURATION) {
            SENTRY_LOG_INFO(
                @"The app start exceeded the max duration of %f seconds. Not measuring app start.",
                SENTRY_APP_START_MAX_DURATION);
            return;
        }

        // On HybridSDKs, we miss the didFinishLaunchNotification and the
        // didBecomeVisibleNotification. Therefore, we can't set the
        // didFinishLaunchingTimestamp, and we can't calculate the appStartDuration. Instead,
        // the SDK provides the information we know and leaves the rest to the HybridSDKs.
        if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
            self.didFinishLaunchingTimestamp =
                [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:0];

            appStartDuration = 0;
        }

        SentryAppStartMeasurement *appStartMeasurement =
            [[SentryAppStartMeasurement alloc] initWithType:appStartType
                                                isPreWarmed:isPreWarmed
                                          appStartTimestamp:appStartTimestamp
                                 runtimeInitSystemTimestamp:sysctl.runtimeInitSystemTimestamp
                                                   duration:appStartDuration
                                       runtimeInitTimestamp:runtimeInit
                              moduleInitializationTimestamp:sysctl.moduleInitializationTimestamp
                                          sdkStartTimestamp:SentrySDK.startTimestamp
                                didFinishLaunchingTimestamp:self.didFinishLaunchingTimestamp];

        SentrySDK.appStartMeasurement = appStartMeasurement;
    };

// With only running this once we know that the process is a new one when the following
// code is executed.
// We need to make sure the block runs on each test instead of only once
#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
    block();
#    else
    static dispatch_once_t once;
    [self.dispatchQueue dispatchOnce:&once block:block];
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)
}

/**
 * This is when the window becomes visible, which is not when the first frame of the app is drawn.
 * When this is posted, the app screen is usually white. The correct time when the first frame is
 * drawn is called in framesTrackerHasNewFrame only when `enablePerformanceV2` is enabled.
 */
- (void)didBecomeVisible
{
    if (!_enablePerformanceV2) {
        [self
            buildAppStartMeasurement:[SentryDependencyContainer.sharedInstance.dateProvider date]];
    }
}

/**
 * This is when the first frame is drawn.
 */
- (void)framesTrackerHasNewFrame:(NSDate *)newFrameDate
{
    [self buildAppStartMeasurement:newFrameDate];
}

- (SentryAppStartType)getStartType
{
    // App launched the first time
    if (self.previousAppState == nil) {
        return SentryAppStartTypeCold;
    }

    SentryAppState *currentAppState = [self.appStateManager buildCurrentAppState];

    // If the release name is different we assume it's an app upgrade
    if (![currentAppState.releaseName isEqualToString:self.previousAppState.releaseName]) {
        return SentryAppStartTypeCold;
    }

    NSTimeInterval intervalSincePreviousBootTime = [self.previousAppState.systemBootTimestamp
        timeIntervalSinceDate:currentAppState.systemBootTimestamp];

    // System rebooted, because the previous boot time is in the past.
    if (intervalSincePreviousBootTime < 0) {
        return SentryAppStartTypeCold;
    }

    // System didn't reboot, previous and current boot time are the same.
    if (intervalSincePreviousBootTime == 0) {
        return SentryAppStartTypeWarm;
    }

    // This should never be reached as we unsubscribe to didBecomeActive after it is called the
    // first time. If the previous boot time is in the future most likely the system time
    // changed and we can't to anything.
    return SentryAppStartTypeUnknown;
}

- (void)didFinishLaunching
{
    self.didFinishLaunchingTimestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
}

- (void)didEnterBackground
{
    self.wasInBackground = YES;
}

- (void)stop
{
    // Remove the observers with the most specific detail possible, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:UIApplicationDidFinishLaunchingNotification
                                                object:nil];

    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:UIWindowDidBecomeVisibleNotification
                                                object:nil];

    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:UIApplicationDidEnterBackgroundNotification
                                                object:nil];

    [self.framesTracker removeListener:self];

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
    self.isRunning = NO;
#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)
}

- (void)dealloc
{
    [self stop];
    // In dealloc it's safe to unsubscribe for all, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

/**
 * Needed for testing, not public.
 */
- (void)setRuntimeInit:(NSDate *)value
{
    runtimeInit = value;
}

@end

#endif // SENTRY_HAS_UIKIT
