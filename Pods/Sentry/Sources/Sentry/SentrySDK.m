#import "SentrySDK.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryANRTrackingIntegration.h"
#import "SentryAppStartMeasurement.h"
#import "SentryAppStateManager.h"
#import "SentryBinaryImageCache.h"
#import "SentryBreadcrumb.h"
#import "SentryClient+Private.h"
#import "SentryCrash.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryMeta.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryOptions+Private.h"
#import "SentryProfilingConditionals.h"
#import "SentryReplayApi.h"
#import "SentrySamplerDecision.h"
#import "SentrySamplingContext.h"
#import "SentryScope.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"
#import "SentryTransactionContext.h"
#import "SentryUIApplication.h"
#import "SentryUseNSExceptionCallstackWrapper.h"
#import "SentryUserFeedbackIntegration.h"

#if TARGET_OS_OSX
#    import "SentryCrashExceptionApplication.h"
#endif // TARGET_OS_MAC

#if SENTRY_HAS_UIKIT
#    import "SentryUIDeviceWrapper.h"
#    import "SentryUIViewControllerPerformanceTracker.h"
#    if TARGET_OS_IOS
#        import "SentryFeedbackAPI.h"
#    endif // TARGET_OS_IOS
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryContinuousProfiler.h"
#    import "SentryProfiler+Private.h"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NSString *const SENTRY_XCODE_PREVIEW_ENVIRONMENT_KEY = @"XCODE_RUNNING_FOR_PREVIEWS";

@interface SentrySDK ()

@property (class) SentryHub *currentHub;

@end

NS_ASSUME_NONNULL_BEGIN
@implementation SentrySDK
static SentryHub *_Nullable currentHub;
static NSObject *currentHubLock;
static BOOL crashedLastRunCalled;
static SentryAppStartMeasurement *sentrySDKappStartMeasurement;
static NSObject *sentrySDKappStartMeasurementLock;
static BOOL _detectedStartUpCrash;
static SentryOptions *_Nullable startOption;
static NSObject *startOptionsLock;

/**
 * @brief We need to keep track of the number of times @c +[startWith...] is called, because our
 * watchdog termination reporting breaks if it's called more than once.
 * @discussion This doesn't just protect from multiple sequential calls to start the SDK, so we
 * can't simply @c dispatch_once the logic inside the start method; there is also a valid workflow
 * where a consumer could start the SDK, then call @c +[close] and then start again, and we want to
 * reenable the integrations.
 */
static NSUInteger startInvocations;
static NSDate *_Nullable startTimestamp = nil;

+ (void)initialize
{
    if (self == [SentrySDK class]) {
        sentrySDKappStartMeasurementLock = [[NSObject alloc] init];
        currentHubLock = [[NSObject alloc] init];
        startOptionsLock = [[NSObject alloc] init];
        startInvocations = 0;
        _detectedStartUpCrash = NO;
    }
}

+ (SentryHub *)currentHub
{
    @synchronized(currentHubLock) {
        if (nil == currentHub) {
            currentHub = [[SentryHub alloc] initWithClient:nil andScope:nil];
        }
        return currentHub;
    }
}

+ (nullable SentryOptions *)options
{
    @synchronized(startOptionsLock) {
        return startOption;
    }
}
#if SENTRY_TARGET_REPLAY_SUPPORTED
+ (SentryReplayApi *)replay
{
    static SentryReplayApi *replay;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ replay = [[SentryReplayApi alloc] init]; });
    return replay;
}
#endif
/** Internal, only needed for testing. */
+ (void)setCurrentHub:(nullable SentryHub *)hub
{
    @synchronized(currentHubLock) {
        currentHub = hub;
    }
}
/** Internal, only needed for testing. */
+ (void)setStartOptions:(nullable SentryOptions *)options
{
    @synchronized(startOptionsLock) {
        startOption = options;
    }
}

+ (nullable id<SentrySpan>)span
{
    return currentHub.scope.span;
}

+ (BOOL)isEnabled
{
    return currentHub != nil && [currentHub getClient] != nil;
}

+ (SentryMetricsAPI *)metrics
{
    return currentHub.metrics;
}

+ (BOOL)crashedLastRunCalled
{
    return crashedLastRunCalled;
}

+ (void)setCrashedLastRunCalled:(BOOL)value
{
    crashedLastRunCalled = value;
}

/**
 * Not public, only for internal use.
 */
+ (void)setAppStartMeasurement:(nullable SentryAppStartMeasurement *)value
{
    @synchronized(sentrySDKappStartMeasurementLock) {
        sentrySDKappStartMeasurement = value;
    }
    if (PrivateSentrySDKOnly.onAppStartMeasurementAvailable) {
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable(value);
    }
}

/**
 * Not public, only for internal use.
 */
+ (nullable SentryAppStartMeasurement *)getAppStartMeasurement
{
    @synchronized(sentrySDKappStartMeasurementLock) {
        return sentrySDKappStartMeasurement;
    }
}

/**
 * Not public, only for internal use.
 */
+ (NSUInteger)startInvocations
{
    return startInvocations;
}

/**
 * Only needed for testing.
 */
+ (void)setStartInvocations:(NSUInteger)value
{
    startInvocations = value;
}

/**
 * Not public, only for internal use.
 */
+ (nullable NSDate *)startTimestamp
{
    return startTimestamp;
}

/**
 * Only needed for testing.
 */
+ (void)setStartTimestamp:(NSDate *)value
{
    startTimestamp = value;
}

+ (void)startWithOptions:(SentryOptions *)options
{
    // We save the options before checking for Xcode preview because
    // we will use this options in the preview
    startOption = options;
    if ([SentryDependencyContainer.sharedInstance.processInfoWrapper
                .environment[SENTRY_XCODE_PREVIEW_ENVIRONMENT_KEY] isEqualToString:@"1"]) {
        // Using NSLog because SentryLog was not initialized yet.
        NSLog(@"[SENTRY] [WARNING] SentrySDK not started. Running from Xcode preview.");
        return;
    }

    [SentrySDKLogSupport configure:options.debug diagnosticLevel:options.diagnosticLevel];

    // We accept the tradeoff that the SDK might not be fully initialized directly after
    // initializing it on a background thread because scheduling the init synchronously on the main
    // thread could lead to deadlocks.
    SENTRY_LOG_DEBUG(@"Starting SDK...");

#if defined(DEBUG) || defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    SENTRY_LOG_DEBUG(@"Configured options: %@", options.debugDescription);
#endif // defined(DEBUG) || defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)

#if TARGET_OS_OSX
    // Reference to SentryCrashExceptionApplication to prevent compiler from stripping it
    [SentryCrashExceptionApplication class];
#endif

    startInvocations++;
    startTimestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];

    SentryClient *newClient = [[SentryClient alloc] initWithOptions:options];
    [newClient.fileManager moveAppStateToPreviousAppState];
    [newClient.fileManager moveBreadcrumbsToPreviousBreadcrumbs];
    [SentryDependencyContainer.sharedInstance
            .scopePersistentStore moveAllCurrentStateToPreviousState];

    SentryScope *scope
        = options.initialScope([[SentryScope alloc] initWithMaxBreadcrumbs:options.maxBreadcrumbs]);

    SENTRY_LOG_DEBUG(@"Dispatching init work required to run on main thread.");
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncOnMainQueue:^{
        SENTRY_LOG_DEBUG(@"SDK main thread init started...");

        // The UIDeviceWrapper needs to start before the Hub, because the Hub
        // enriches the scope, which calls the UIDeviceWrapper.
#if SENTRY_HAS_UIKIT
        [SentryDependencyContainer.sharedInstance.uiDeviceWrapper start];
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

        // The Hub needs to be initialized with a client so that closing a session
        // can happen.
        SentryHub *hub = [[SentryHub alloc] initWithClient:newClient andScope:scope];
        [SentrySDK setCurrentHub:hub];

        [SentryCrashWrapper.sharedInstance startBinaryImageCache];
        [SentryDependencyContainer.sharedInstance.binaryImageCache start];

        [SentrySDK installIntegrations];

#if SENTRY_TARGET_PROFILING_SUPPORTED
        sentry_sdkInitProfilerTasks(options, hub);
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }];

    SENTRY_LOG_DEBUG(@"SDK initialized! Version: %@", SentryMeta.versionString);
}

+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
{
    SentryOptions *options = [[SentryOptions alloc] init];
    configureOptions(options);
    [SentrySDK startWithOptions:options];
}

+ (void)captureFatalEvent:(SentryEvent *)event
{
    [SentrySDK.currentHub captureFatalEvent:event];
}

+ (void)captureFatalEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    [SentrySDK.currentHub captureFatalEvent:event withScope:scope];
}

#if SENTRY_HAS_UIKIT

+ (void)captureFatalAppHangEvent:(SentryEvent *)event
{
    [SentrySDK.currentHub captureFatalAppHangEvent:event];
}

#endif // SENTRY_HAS_UIKIT

+ (SentryId *)captureEvent:(SentryEvent *)event
{
    return [SentrySDK captureEvent:event withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureEvent:event withScope:scope];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureEvent:event withScope:scope];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation
{
    return [SentrySDK.currentHub startTransactionWithName:name operation:operation];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope
{
    return [SentrySDK.currentHub startTransactionWithName:name
                                                operation:operation
                                              bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext
                                                 bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext
                                                 bindToScope:bindToScope
                                       customSamplingContext:customSamplingContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext
                                       customSamplingContext:customSamplingContext];
}

+ (SentryId *)captureError:(NSError *)error
{
    return [SentrySDK captureError:error withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *_Nonnull))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureError:error withScope:scope];
}

+ (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureError:error withScope:scope];
}

+ (SentryId *)captureException:(NSException *)exception
{
    return [SentrySDK captureException:exception withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureException:exception withScope:scope];
}

+ (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureException:exception withScope:scope];
}

#if TARGET_OS_OSX

+ (SentryId *)captureCrashOnException:(NSException *)exception
{
    SentryUseNSExceptionCallstackWrapper *wrappedException =
        [[SentryUseNSExceptionCallstackWrapper alloc]
                        initWithName:exception.name
                              reason:exception.reason
                            userInfo:exception.userInfo
            callStackReturnAddresses:exception.callStackReturnAddresses];
    return [SentrySDK captureException:wrappedException withScope:SentrySDK.currentHub.scope];
}

#endif // TARGET_OS_OSX

+ (SentryId *)captureMessage:(NSString *)message
{
    return [SentrySDK captureMessage:message withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope *))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureMessage:message withScope:scope];
}

+ (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureMessage:message withScope:scope];
}

/**
 * Needed by hybrid SDKs as react-native to synchronously capture an envelope.
 */
+ (void)captureEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK.currentHub captureEnvelope:envelope];
}

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK.currentHub storeEnvelope:envelope];
}

#if !SDK_V9
+ (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    [SentrySDK.currentHub captureUserFeedback:userFeedback];
}
#endif // !SDK_V9

+ (void)captureFeedback:(SentryFeedback *)feedback
{
    [SentrySDK.currentHub captureFeedback:feedback];
}

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

+ (SentryFeedbackAPI *)feedback
{
    static SentryFeedbackAPI *feedbackAPI;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ feedbackAPI = [[SentryFeedbackAPI alloc] init]; });
    return feedbackAPI;
}

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentrySDK.currentHub addBreadcrumb:crumb];
}

+ (void)configureScope:(void (^)(SentryScope *scope))callback
{
    [SentrySDK.currentHub configureScope:callback];
}

+ (void)setUser:(SentryUser *_Nullable)user
{
    if (![SentrySDK isEnabled]) {
        // We must log with level fatal because only fatal messages get logged even when the SDK
        // isn't started. We've seen multiple times that users try to set the user before starting
        // the SDK, and it confuses them. Ideally, we would do something to store the user and set
        // it once we start the SDK, but this is a breaking change, so we live with the workaround
        // for now.
        SENTRY_LOG_FATAL(@"The SDK is disabled, so setUser doesn't work. Please ensure to start "
                         @"the SDK before setting the user.");
    }

    [SentrySDK.currentHub setUser:user];
}

+ (BOOL)crashedLastRun
{
    return SentryDependencyContainer.sharedInstance.crashReporter.crashedLastLaunch;
}

+ (BOOL)detectedStartUpCrash
{
    return _detectedStartUpCrash;
}

+ (void)setDetectedStartUpCrash:(BOOL)value
{
    _detectedStartUpCrash = value;
}

+ (void)startSession
{
    [SentrySDK.currentHub startSession];
}

+ (void)endSession
{
    [SentrySDK.currentHub endSession];
}

/**
 * Install integrations and keeps ref in @c SentryHub.integrations
 */
+ (void)installIntegrations
{
    if (nil == [SentrySDK.currentHub getClient]) {
        // Gatekeeper
        return;
    }
    SentryOptions *options = [SentrySDK.currentHub getClient].options;
    NSMutableArray<NSString *> *integrationNames =
        [SentrySDK.currentHub getClient].options.integrations.mutableCopy;

    NSArray<Class> *defaultIntegrations = SentryOptions.defaultIntegrationClasses;

    // Since 8.22.0, we use a precompiled XCFramework for SPM, which can lead to Sentry's
    // definition getting duplicated in the app with a warning “SentrySDK is defined in both
    // ModuleA and ModuleB”. This doesn't happen when users use Sentry-Dynamic and
    // when compiling Sentry from source via SPM. Due to the duplication, some users didn't
    // see any crashes reported to Sentry cause the SentryCrashReportSink couldn't find
    // a hub bound to the SentrySDK, and it dropped the crash events. This problem
    // is fixed now by using a dictionary that links the classes with their names
    // so we can quickly check whether that class is in the option integrations collection.
    // We cannot load the class itself with NSClassFromString because doing so may load a class
    // that was duplicated in another module, leading to undefined behavior.
    NSMutableDictionary<NSString *, Class> *integrationDictionary =
        [[NSMutableDictionary alloc] init];

    for (Class integrationClass in defaultIntegrations) {
        integrationDictionary[NSStringFromClass(integrationClass)] = integrationClass;
    }

    for (NSString *integrationName in integrationNames) {
        Class integrationClass
            = integrationDictionary[integrationName] ?: NSClassFromString(integrationName);
        if (nil == integrationClass) {
            SENTRY_LOG_ERROR(@"[SentryHub doInstallIntegrations] "
                             @"couldn't find \"%@\" -> skipping.",
                integrationName);
            continue;
        } else if ([SentrySDK.currentHub isIntegrationInstalled:integrationClass]) {
            SENTRY_LOG_ERROR(
                @"[SentryHub doInstallIntegrations] already installed \"%@\" -> skipping.",
                integrationName);
            continue;
        }
        id<SentryIntegrationProtocol> integrationInstance = [[integrationClass alloc] init];
        BOOL shouldInstall = [integrationInstance installWithOptions:options];

        if (shouldInstall) {
            SENTRY_LOG_DEBUG(@"Integration installed: %@", integrationName);
            [SentrySDK.currentHub addInstalledIntegration:integrationInstance name:integrationName];
        }
    }
}

+ (void)reportFullyDisplayed
{
    [SentrySDK.currentHub reportFullyDisplayed];
}

+ (void)pauseAppHangTracking
{
    SentryANRTrackingIntegration *anrTrackingIntegration
        = (SentryANRTrackingIntegration *)[SentrySDK.currentHub
            getInstalledIntegration:[SentryANRTrackingIntegration class]];

    [anrTrackingIntegration pauseAppHangTracking];
}

+ (void)resumeAppHangTracking
{
    SentryANRTrackingIntegration *anrTrackingIntegration
        = (SentryANRTrackingIntegration *)[SentrySDK.currentHub
            getInstalledIntegration:[SentryANRTrackingIntegration class]];

    [anrTrackingIntegration resumeAppHangTracking];
}

+ (void)flush:(NSTimeInterval)timeout
{
    [SentrySDK.currentHub flush:timeout];
}

/**
 * Closes the SDK and uninstalls all the integrations.
 */
+ (void)close
{
    SENTRY_LOG_DEBUG(@"Starting to close SDK.");

#if SENTRY_TARGET_PROFILING_SUPPORTED
    [SentryContinuousProfiler stop];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    startTimestamp = nil;

    SentryHub *hub = SentrySDK.currentHub;
    [hub removeAllIntegrations];

    SENTRY_LOG_DEBUG(@"Uninstalled all integrations.");

#if SENTRY_HAS_UIKIT
    // force the AppStateManager to unsubscribe, see
    // https://github.com/getsentry/sentry-cocoa/issues/2455
    [[SentryDependencyContainer sharedInstance].appStateManager stopWithForce:YES];
#endif

    [hub close];
    [hub bindClient:nil];

    [SentrySDK setCurrentHub:nil];

    [SentryCrashWrapper.sharedInstance stopBinaryImageCache];
    [SentryDependencyContainer.sharedInstance.binaryImageCache stop];

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    [SentryDependencyContainer.sharedInstance.uiDeviceWrapper stop];
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

    [SentryDependencyContainer reset];
    SENTRY_LOG_DEBUG(@"SDK closed!");
}

#ifndef __clang_analyzer__
// Code not to be analyzed
+ (void)crash
{
    int *p = 0;
    *p = 0;
}
#endif

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (void)startProfiler
{
    SentryOptions *options = currentHub.client.options;
    if (![options isContinuousProfilingEnabled]) {
        SENTRY_LOG_WARN(
            @"You must disable trace profiling by setting SentryOptions.profilesSampleRate and "
            @"SentryOptions.profilesSampler to nil (which is the default initial value for both "
            @"properties, so you can also just remove those lines from your configuration "
            @"altogether) before attempting to start a continuous profiling session. This behavior "
            @"relies on deprecated options and will change in a future version.");
        return;
    }

    if (options.profiling != nil) {
        if (options.profiling.lifecycle == SentryProfileLifecycleTrace) {
            SENTRY_LOG_WARN(
                @"The profiling lifecycle is set to trace, so you cannot start profile sessions "
                @"manually. See SentryProfileLifecycle for more information.");
            return;
        }

        if (sentry_profilerSessionSampleDecision.decision != kSentrySampleDecisionYes) {
            SENTRY_LOG_DEBUG(
                @"The profiling session has been sampled out, no profiling will take place.");
            return;
        }
    }

    if ([SentryContinuousProfiler isCurrentlyProfiling]) {
        SENTRY_LOG_WARN(@"There is already a profile session running.");
        return;
    }

    [SentryContinuousProfiler start];
}

+ (void)stopProfiler
{
    SentryOptions *options = currentHub.client.options;
    if (![options isContinuousProfilingEnabled]) {
        SENTRY_LOG_WARN(
            @"You must disable trace profiling by setting SentryOptions.profilesSampleRate and "
            @"SentryOptions.profilesSampler to nil (which is the default initial value for both "
            @"properties, so you can also just remove those lines from your configuration "
            @"altogether) before attempting to stop a continuous profiling session. This behavior "
            @"relies on deprecated options and will change in a future version.");
        return;
    }

    if (options.profiling != nil && options.profiling.lifecycle == SentryProfileLifecycleTrace) {
        SENTRY_LOG_WARN(
            @"The profiling lifecycle is set to trace, so you cannot stop profile sessions "
            @"manually. See SentryProfileLifecycle for more information.");
        return;
    }

    if (![SentryContinuousProfiler isCurrentlyProfiling]) {
        SENTRY_LOG_WARN(@"No profile session to stop.");
        return;
    }

    [SentryContinuousProfiler stop];
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#if SENTRY_HAS_UIKIT

/** Only needed for testing. We can't use `SENTRY_TEST || SENTRY_TEST_CI` because we call this from
 * the iOS-Swift sample app. */
+ (nullable NSArray<NSString *> *)relevantViewControllersNames
{
    return SentryDependencyContainer.sharedInstance.application.relevantViewControllersNames;
}
#endif // SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END
