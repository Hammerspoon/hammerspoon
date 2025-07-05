#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Integration to setup automatic performance tracking.
 * Automatic UI performance setup can be avoided by setting @c enableAutoPerformanceTracing to @c NO
 * in @c SentryOptions during SentrySDK initialization.
 */
@interface SentryPerformanceTrackingIntegration : SentryBaseIntegration

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
