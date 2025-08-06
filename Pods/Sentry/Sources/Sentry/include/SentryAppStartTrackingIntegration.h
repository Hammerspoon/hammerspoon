#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Tracks cold and warm app start time for iOS, tvOS, and Mac Catalyst.
 */
@interface SentryAppStartTrackingIntegration : SentryBaseIntegration

- (void)stop;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
