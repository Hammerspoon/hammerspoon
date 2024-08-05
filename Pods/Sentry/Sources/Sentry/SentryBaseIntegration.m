#import "SentryBaseIntegration.h"
#import "SentryCrashWrapper.h"
#import "SentryLog.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>
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
        if (!options.enableAppHangTracking) {
            [self logWithOptionName:@"enableAppHangTracking"];
            return NO;
        }

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

    if (integrationOptions & kIntegrationOptionEnableReplay) {
        if (@available(iOS 16.0, tvOS 16.0, *)) {
            if (options.experimental.sessionReplay.errorSampleRate == 0
                && options.experimental.sessionReplay.sessionSampleRate == 0) {
                [self logWithOptionName:@"sessionReplaySettings"];
                return NO;
            }
        } else {
            [self logWithReason:@"Session replay requires iOS 16 or above"];
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
