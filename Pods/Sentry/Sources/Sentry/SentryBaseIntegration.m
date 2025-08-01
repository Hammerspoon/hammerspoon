#import "SentryBaseIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import <SentryDependencyContainer.h>
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryBaseIntegration

- (NSString *)integrationName
{
    return NSStringFromClass([self classForCoder]);
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    return [self shouldBeEnabledWithOptions:options];
}

- (void)logWithOptionName:(NSString *)optionName
{
    [self logWithReason:[NSString stringWithFormat:@"because %@ is disabled", optionName]];
}

- (void)logWithReason:(NSString *)reason
{
    SENTRY_LOG_DEBUG(@"Not going to enable %@ %@.", self.integrationName, reason);
}

- (BOOL)shouldBeEnabledWithOptions:(SentryOptions *)options
{
    SentryIntegrationOption integrationOptions = [self integrationOptions];

    if (integrationOptions & kIntegrationOptionNone) {
        return YES;
    }

    if ((integrationOptions & kIntegrationOptionEnableAutoSessionTracking)
        && !options.enableAutoSessionTracking) {
        [self logWithOptionName:@"enableAutoSessionTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableWatchdogTerminationTracking)
        && !options.enableWatchdogTerminationTracking) {
        [self logWithOptionName:@"enableWatchdogTerminationTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableAutoPerformanceTracing)
        && !options.enableAutoPerformanceTracing) {
        [self logWithOptionName:@"enableAutoPerformanceTracing"];
        return NO;
    }

#if SENTRY_HAS_UIKIT
    if ((integrationOptions & kIntegrationOptionEnableUIViewControllerTracing)
        && !options.enableUIViewControllerTracing) {
        [self logWithOptionName:@"enableUIViewControllerTracing"];
        return NO;
    }

#    if SENTRY_HAS_UIKIT
    if ((integrationOptions & kIntegrationOptionAttachScreenshot) && !options.attachScreenshot) {
        [self logWithOptionName:@"attachScreenshot"];
        return NO;
    }
#    endif // SENTRY_HAS_UIKIT

    if ((integrationOptions & kIntegrationOptionEnableUserInteractionTracing)
        && !options.enableUserInteractionTracing) {
        [self logWithOptionName:@"enableUserInteractionTracing"];
        return NO;
    }
#endif

    if (integrationOptions & kIntegrationOptionEnableAppHangTracking) {
#if SENTRY_HAS_UIKIT
        if (!options.enableAppHangTracking && !options.enableAppHangTrackingV2) {
            [self logWithOptionName:@"enableAppHangTracking && enableAppHangTrackingV2"];
            return NO;
        }
#else
        if (!options.enableAppHangTracking) {
            [self logWithOptionName:@"enableAppHangTracking"];
            return NO;
        }
#endif // SENTRY_HAS_UIKIT

        if (options.appHangTimeoutInterval == 0) {
            [self logWithReason:@"because appHangTimeoutInterval is 0"];
            return NO;
        }
    }

    if ((integrationOptions & kIntegrationOptionEnableNetworkTracking)
        && !options.enableNetworkTracking) {
        [self logWithOptionName:@"enableNetworkTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableFileIOTracing)
        && !options.enableFileIOTracing) {
        [self logWithOptionName:@"enableFileIOTracing"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableNetworkBreadcrumbs)
        && !options.enableNetworkBreadcrumbs) {
        [self logWithOptionName:@"enableNetworkBreadcrumbs"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableCoreDataTracing)
        && !options.enableCoreDataTracing) {
        [self logWithOptionName:@"enableCoreDataTracing"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableSwizzling) && !options.enableSwizzling) {
        [self logWithOptionName:@"enableSwizzling"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionEnableAutoBreadcrumbTracking)
        && !options.enableAutoBreadcrumbTracking) {
        [self logWithOptionName:@"enableAutoBreadcrumbTracking"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionIsTracingEnabled) && !options.isTracingEnabled) {
        [self logWithOptionName:@"isTracingEnabled"];
        return NO;
    }

    if ((integrationOptions & kIntegrationOptionDebuggerNotAttached) &&
        [SentryDependencyContainer.sharedInstance.crashWrapper isBeingTraced]) {
        [self logWithReason:@"because the debugger is attached"];
        return NO;
    }

#if SENTRY_HAS_UIKIT
    if ((integrationOptions & kIntegrationOptionAttachViewHierarchy)
        && !options.attachViewHierarchy) {
        [self logWithOptionName:@"attachViewHierarchy"];
        return NO;
    }
#endif
#if SENTRY_TARGET_REPLAY_SUPPORTED
    if (integrationOptions & kIntegrationOptionEnableReplay) {
        if (options.sessionReplay.onErrorSampleRate == 0
            && options.sessionReplay.sessionSampleRate == 0) {
            [self logWithOptionName:@"sessionReplaySettings"];
            return NO;
        }
    }
#endif
    if ((integrationOptions & kIntegrationOptionEnableCrashHandler)
        && !options.enableCrashHandler) {
        [self logWithOptionName:@"enableCrashHandler"];
        return NO;
    }

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
        if ((integrationOptions & kIntegrationOptionEnableMetricKit) && !options.enableMetricKit) {
            [self logWithOptionName:@"enableMetricKit"];
            return NO;
        }
    }
#endif

    // The frames tracker runs when tracing is enabled or AppHangsV2. We have to use an extra option
    // for this.
    if (integrationOptions & kIntegrationOptionStartFramesTracker) {

#if SENTRY_HAS_UIKIT
        BOOL performanceDisabled
            = !options.enableAutoPerformanceTracing || !options.isTracingEnabled;
        BOOL appHangsV2Disabled = options.isAppHangTrackingV2Disabled;

        if (performanceDisabled && appHangsV2Disabled) {
            if (appHangsV2Disabled) {
                SENTRY_LOG_DEBUG(@"Not going to enable %@ because enableAppHangTrackingV2 is "
                                 @"disabled or the appHangTimeoutInterval is 0.",
                    self.integrationName);
            }

            if (performanceDisabled) {
                SENTRY_LOG_DEBUG(@"Not going to enable %@ because enableAutoPerformanceTracing and "
                                 @"isTracingEnabled are disabled.",
                    self.integrationName);
            }

            return NO;
        }
#endif // SENTRY_HAS_UIKIT
    }

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionNone;
}

- (void)uninstall
{
}

@end

NS_ASSUME_NONNULL_END
