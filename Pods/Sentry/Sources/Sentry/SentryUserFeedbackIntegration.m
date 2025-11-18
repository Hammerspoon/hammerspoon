#import "SentryUserFeedbackIntegration.h"
#import "SentryDependencyContainer.h"
#import "SentryInternalDefines.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@interface SentryUserFeedbackIntegration () <SentryUserFeedbackIntegrationDriverDelegate>
@end

@implementation SentryUserFeedbackIntegration {
    SentryUserFeedbackIntegrationDriver *_driver;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (options.userFeedbackConfiguration == nil) {
        return NO;
    }

    // The screenshot source is coupled to the options, but due to the dependency container being
    // tightly to the options anyways, it was decided to not pass it to the container.
    SentryScreenshotSource *screenshotSource
        = SentryDependencyContainer.sharedInstance.screenshotSource;
    _driver = [[SentryUserFeedbackIntegrationDriver alloc]
        initWithConfiguration:SENTRY_UNWRAP_NULLABLE(SentryUserFeedbackConfiguration,
                                  options.userFeedbackConfiguration)
                     delegate:self
             screenshotSource:screenshotSource];
    return YES;
}

- (void)showWidget
{
    [_driver showWidget];
}

- (void)hideWidget
{
    [_driver hideWidget];
}

// MARK: SentryUserFeedbackIntegrationDriverDelegate

- (void)captureWithFeedback:(SentryFeedback *)feedback
{
    [SentrySDK captureFeedback:feedback];
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
