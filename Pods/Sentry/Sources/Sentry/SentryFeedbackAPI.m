#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import "SentryFeedbackAPI.h"
#    import "SentryHub+Private.h"
#    import "SentryLogC.h"
#    import "SentrySDK+Private.h"
#    import "SentryUserFeedbackIntegration.h"

@implementation SentryFeedbackAPI

- (void)showWidget
{
    if (@available(iOS 13.0, *)) {
        SentryUserFeedbackIntegration *feedback =
            [[SentrySDK currentHub] getInstalledIntegration:[SentryUserFeedbackIntegration class]];
        [feedback showWidget];
    } else {
        SENTRY_LOG_WARN(@"Sentry User Feedback is only available on iOS 13 or later.");
    }
}

- (void)hideWidget
{
    if (@available(iOS 13.0, *)) {
        SentryUserFeedbackIntegration *feedback =
            [SentrySDK.currentHub getInstalledIntegration:[SentryUserFeedbackIntegration class]];
        [feedback hideWidget];
    } else {
        SENTRY_LOG_WARN(@"Sentry User Feedback is only available on iOS 13 or later.");
    }
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
