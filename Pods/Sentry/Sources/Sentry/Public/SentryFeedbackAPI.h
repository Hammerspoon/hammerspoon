#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface SentryFeedbackAPI : NSObject

/**
 * Show the feedback widget button.
 * @warning This is an experimental feature and may still have bugs.
 * @seealso See @c SentryOptions.configureUserFeedback to configure the widget.
 * @note User feedback widget is only available for iOS 13 or later.
 */
- (void)showWidget API_AVAILABLE(ios(13.0));

/**
 * Hide the feedback widget button.
 * @warning This is an experimental feature and may still have bugs.
 * @seealso See @c SentryOptions.configureUserFeedback to configure the widget.
 * @note User feedback widget is only available for iOS 13 or later.
 */
- (void)hideWidget API_AVAILABLE(ios(13.0));

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
