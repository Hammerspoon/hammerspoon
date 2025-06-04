#if __has_include(<Sentry/SentryBaseIntegration.h>)
#    import <Sentry/SentryBaseIntegration.h>
#else
#    import "SentryBaseIntegration.h"
#endif

#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_TARGET_REPLAY_SUPPORTED

@protocol SentryReplayBreadcrumbConverter;
@protocol SentryViewScreenshotProvider;

@interface SentrySessionReplayIntegration : SentryBaseIntegration

- (instancetype)initForManualUse:(nonnull SentryOptions *)options;

/**
 * Captures Replay. Used by the Hybrid SDKs.
 */
- (BOOL)captureReplay;

/**
 * Configure session replay with different breadcrumb converter
 * and screeshot provider. Used by the Hybrid SDKs.
 * If can pass nil to avoid changing the property.
 */
- (void)configureReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
         screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider;

- (void)pause;

- (void)resume;

- (void)stop;

- (void)start;

- (void)showMaskPreview:(CGFloat)opacity;

- (void)hideMaskPreview;

@end
#endif // SENTRY_TARGET_REPLAY_SUPPORTED
NS_ASSUME_NONNULL_END
