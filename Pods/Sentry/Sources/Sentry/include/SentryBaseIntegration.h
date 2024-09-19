#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, SentryIntegrationOption) {
    kIntegrationOptionNone = 0,
    kIntegrationOptionEnableAutoSessionTracking = 1 << 0,
    kIntegrationOptionEnableWatchdogTerminationTracking = 1 << 1,
    kIntegrationOptionEnableAutoPerformanceTracing = 1 << 2,
    kIntegrationOptionEnableUIViewControllerTracing = 1 << 3,
    kIntegrationOptionAttachScreenshot = 1 << 4,
    kIntegrationOptionEnableUserInteractionTracing = 1 << 5,
    kIntegrationOptionEnableAppHangTracking = 1 << 6,
    kIntegrationOptionEnableNetworkTracking = 1 << 7,
    kIntegrationOptionEnableFileIOTracing = 1 << 8,
    kIntegrationOptionEnableNetworkBreadcrumbs = 1 << 9,
    kIntegrationOptionEnableCoreDataTracing = 1 << 10,
    kIntegrationOptionEnableSwizzling = 1 << 11,
    kIntegrationOptionEnableAutoBreadcrumbTracking = 1 << 12,
    kIntegrationOptionIsTracingEnabled = 1 << 13,
    kIntegrationOptionDebuggerNotAttached = 1 << 14,
    kIntegrationOptionAttachViewHierarchy = 1 << 15,
    kIntegrationOptionEnableCrashHandler = 1 << 16,
    kIntegrationOptionEnableMetricKit = 1 << 17,
    kIntegrationOptionEnableReplay = 1 << 18,
    kIntegrationOptionEnableAppHangTrackingV2 = 1 << 19,
};

@class SentryOptions;

@interface SentryBaseIntegration : NSObject

- (NSString *)integrationName;
- (BOOL)installWithOptions:(SentryOptions *)options;
- (void)logWithOptionName:(NSString *)optionName;
- (void)logWithReason:(NSString *)reason;
- (BOOL)shouldBeEnabledWithOptions:(SentryOptions *)options;
- (SentryIntegrationOption)integrationOptions;
- (void)uninstall;
@end

NS_ASSUME_NONNULL_END
