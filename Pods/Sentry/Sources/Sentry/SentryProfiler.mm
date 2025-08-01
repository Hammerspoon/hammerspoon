#import "SentryProfiler+Private.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryClient+Private.h"
#    import "SentryContinuousProfiler.h"
#    import "SentryDependencyContainer.h"
#    import "SentryFileManager.h"
#    import "SentryFramesTracker.h"
#    import "SentryHub+Private.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentryLogC.h"
#    import "SentryMetricProfiler.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfilerState+ObjCpp.h"
#    import "SentryProfilerTestHelpers.h"
#    import "SentrySDK+Private.h"
#    import "SentrySampling.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryScreenFrames.h"
#    import "SentrySwift.h"
#    import "SentryTime.h"

#    if SENTRY_HAS_UIKIT
#        import "SentryFramesTracker.h"
#        import "SentryNSNotificationCenterWrapper.h"
#        import "SentryUIViewControllerPerformanceTracker.h"
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

using namespace sentry::profiling;

SentrySamplerDecision *_Nullable sentry_profilerSessionSampleDecision;

namespace {

static const int kSentryProfilerFrequencyHz = 101;

} // namespace

#    pragma mark - Public

void
sentry_reevaluateSessionSampleRate(float sessionSampleRate)
{
    sentry_profilerSessionSampleDecision = sentry_sampleProfileSession(sessionSampleRate);
}

void
sentry_configureContinuousProfiling(SentryOptions *options)
{
    if (![options isContinuousProfilingEnabled]) {
        if (options.configureProfiling != nil) {
            SENTRY_LOG_WARN(@"In order to configure SentryProfileOptions you must remove "
                            @"configuration of the older SentryOptions.profilesSampleRate, "
                            @"SentryOptions.profilesSampler and/or SentryOptions.enableProfiling");
        }
        return;
    }

    if (options.configureProfiling == nil) {
        SENTRY_LOG_DEBUG(@"Continuous profiling V2 configuration not set by SDK consumer, nothing "
                         @"to do here.");
        return;
    }

    options.profiling = [[SentryProfileOptions alloc] init];
    options.configureProfiling(options.profiling);

    if (options.profiling.lifecycle == SentryProfileLifecycleTrace && !options.isTracingEnabled) {
        SENTRY_LOG_WARN(
            @"Tracing must be enabled in order to configure profiling with trace lifecycle.");
        return;
    }

    sentry_reevaluateSessionSampleRate(options.profiling.sessionSampleRate);

    SENTRY_LOG_DEBUG(@"Configured profiling options: <%@: {\n  lifecycle: %@\n  sessionSampleRate: "
                     @"%.2f\n  profileAppStarts: %@\n}",
        options.profiling,
        options.profiling.lifecycle == SentryProfileLifecycleTrace ? @"trace" : @"manual",
        options.profiling.sessionSampleRate, options.profiling.profileAppStarts ? @"YES" : @"NO");
}

void
sentry_sdkInitProfilerTasks(SentryOptions *options, SentryHub *hub)
{
    sentry_configureContinuousProfiling(options);

    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        // get the configuration options from the last time the launch config was written; it may be
        // different than the new options the SDK was just started with
        const auto configDict = sentry_appLaunchProfileConfiguration();
        const auto profileIsContinuousV1 =
            [configDict[kSentryLaunchProfileConfigKeyContinuousProfiling] boolValue];
        const auto profileIsContinuousV2 =
            [configDict[kSentryLaunchProfileConfigKeyContinuousProfilingV2] boolValue];
        const auto v2LifecycleValue
            = configDict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle];
        const auto v2Lifecycle = (SentryProfileLifecycle)
            [configDict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle] intValue];
        const auto v2LifecycleIsManual = profileIsContinuousV2 && v2LifecycleValue != nil
            && v2Lifecycle == SentryProfileLifecycleManual;

        BOOL shouldStopAndTransmitLaunchProfile = YES;

#    if SENTRY_HAS_UIKIT
        const auto v2LifecycleIsTrace = profileIsContinuousV2 && v2LifecycleValue != nil
            && v2Lifecycle == SentryProfileLifecycleTrace;
        const auto profileIsCorrelatedToTrace = !profileIsContinuousV2 || v2LifecycleIsTrace;
        SentryUIViewControllerPerformanceTracker *performanceTracker =
            [SentryDependencyContainer.sharedInstance uiViewControllerPerformanceTracker];
        if (profileIsCorrelatedToTrace && performanceTracker.alwaysWaitForFullDisplay) {
            SENTRY_LOG_DEBUG(@"Will wait to stop launch profile correlated to a trace until full "
                             @"display reported.");
            shouldStopAndTransmitLaunchProfile = NO;
        }
#    endif // SENTRY_HAS_UIKIT

        if (profileIsContinuousV1 || v2LifecycleIsManual) {
            SENTRY_LOG_DEBUG(
                @"Continuous manual launch profiles aren't stopped on calls to SentrySDK.start, "
                @"not stopping profile.");
            shouldStopAndTransmitLaunchProfile = NO;
        }

        if (shouldStopAndTransmitLaunchProfile) {
            SENTRY_LOG_DEBUG(@"Stopping launch profile in SentrySDK.start because there will "
                             @"be no automatic trace to attach it to.");
            sentry_stopAndTransmitLaunchProfile(hub);
        }

        sentry_configureLaunchProfiling(options);
    }];
}

@implementation SentryProfiler {
    std::unique_ptr<SamplingProfiler> _samplingProfiler;
}

+ (void)load
{
#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
    // we want to allow starting a launch profile from here for UI tests, but not unit tests
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] == nil) {
        return;
    }

    // the samples apps may want to wipe the data like before UI test case runs, or manually during
    // development, to remove any launch config files that might be present before launching the app
    // initially, however we need to make sure to remove stale versions of the file before it gets
    // used to potentially start a launch profile that shouldn't have started, so we check here for
    // this
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--io.sentry.wipe-data"]) {
        removeSentryStaticBasePath();
    }
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

    sentry_startLaunchProfile();
}

- (instancetype)initWithMode:(SentryProfilerMode)mode
{
    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);

#    if SENTRY_HAS_UIKIT
    // the frame tracker may not be running if SentryOptions.enableAutoPerformanceTracing is NO
    [SentryDependencyContainer.sharedInstance.framesTracker start];
#    endif // SENTRY_HAS_UIKIT

    [self start];

    self.metricProfiler = [[SentryMetricProfiler alloc] initWithMode:mode];
    [self.metricProfiler start];

#    if SENTRY_HAS_UIKIT
    if (mode == SentryProfilerModeTrace) {
        [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
            addObserver:self
               selector:@selector(backgroundAbort)
                   name:UIApplicationWillResignActiveNotification];
    }
#    endif // SENTRY_HAS_UIKIT

    return self;
}

#    pragma mark - Private

- (void)backgroundAbort
{
    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Current profiler is not running.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to app moving to background.", self);
    [self stopForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

- (void)stopForReason:(SentryProfilerTruncationReason)reason
{
    sentry_isTracingAppLaunch = NO;
    [self.metricProfiler stop];
    self.truncationReason = reason;

    if (![self isRunning]) {
        SENTRY_LOG_WARN(@"Profiler is not currently running.");
        return;
    }

#    if SENTRY_HAS_UIKIT
    // if SentryOptions.enableAutoPerformanceTracing is NO and appHangsV2Disabled, which uses the
    // frames tracker, is YES, then we need to stop the frames tracker from running outside of
    // profiles because it isn't needed for anything else

    BOOL autoPerformanceTracingDisabled
        = ![[[[SentrySDK currentHub] getClient] options] enableAutoPerformanceTracing];
    BOOL appHangsV2Disabled =
        [[[[SentrySDK currentHub] getClient] options] isAppHangTrackingV2Disabled];

    if (autoPerformanceTracingDisabled && appHangsV2Disabled) {
        [SentryDependencyContainer.sharedInstance.framesTracker stop];
    }
#    endif // SENTRY_HAS_UIKIT

    _samplingProfiler->stopSampling();
    SENTRY_LOG_DEBUG(@"Stopped profiler %@.", self);
}

- (void)start
{
    if (sentry_threadSanitizerIsPresent()) {
        SENTRY_LOG_DEBUG(@"Disabling profiling when running with TSAN");
        return;
    }

    if (_samplingProfiler != nullptr) {
        // This theoretically shouldn't be possible as long as we're checking for nil and running
        // profilers in +[start], but technically we should still cover nilness here as well. So,
        // we'll just bail and let the current one continue to do whatever it's already doing:
        // either currently sampling, or waiting to be queried and provide profile data to
        // SentryTracer for upload with transaction envelopes, so as not to lose that data.
        SENTRY_LOG_WARN(
            @"There is already a private profiler instance present, will not start a new one.");
        return;
    }

    // Pop the clang diagnostic to ignore unreachable code for TSAN runs
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
#            pragma clang diagnostic pop
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

    SENTRY_LOG_DEBUG(@"Starting profiler.");

    SentryProfilerState *const state = [[SentryProfilerState alloc] init];
    self.state = state;
    _samplingProfiler = std::make_unique<SamplingProfiler>(
        [state](auto &backtrace) {
            Backtrace backtraceCopy = backtrace;
            backtraceCopy.absoluteTimestamp
                = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
            @autoreleasepool {
                [state appendBacktrace:backtraceCopy];
            }
        },
        kSentryProfilerFrequencyHz);
    _samplingProfiler->startSampling();
}

- (BOOL)isRunning
{
    if (_samplingProfiler == nullptr) {
        return NO;
    }
    return _samplingProfiler->isSampling();
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
