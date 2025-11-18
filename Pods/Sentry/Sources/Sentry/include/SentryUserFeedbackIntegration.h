#import "SentryBaseIntegration.h"

#import "SentryDefines.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
NS_EXTENSION_UNAVAILABLE("Sentry User Feedback UI cannot be used from app extensions.")
@interface SentryUserFeedbackIntegration : SentryBaseIntegration
- (void)showWidget;
- (void)hideWidget;
@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
