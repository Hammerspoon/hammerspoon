#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class UIView;

NS_ASSUME_NONNULL_BEGIN

@interface SentryReplayApi : NSObject

/**
 * Marks this view to be masked during replays.
 */
- (void)maskView:(UIView *)view NS_SWIFT_NAME(maskView(_:));

/**
 * Marks this view to not be masked during redact step of session replay.
 */
- (void)unmaskView:(UIView *)view NS_SWIFT_NAME(unmaskView(_:));

/**
 * Pauses the replay.
 */
- (void)pause;

/**
 * Resumes the ongoing replay.
 */
- (void)resume;

/**
 * Start recording a session replay if not started.
 */
- (void)start;

/**
 * Stop the current session replay recording.
 */
- (void)stop;

/**
 * Shows an overlay on the app to debug session replay masking.
 *
 * By calling this function an overlay will appear covering the parts
 * of the app that will be masked for the session replay.
 * This will only work if the debbuger is attached and it will
 * cause some slow frames.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this is production.
 */
- (void)showMaskPreview;

/**
 * Shows an overlay on the app to debug session replay masking.
 *
 * By calling this function an overlay will appear covering the parts
 * of the app that will be masked for the session replay.
 * This will only work if the debbuger is attached and it will
 * cause some slow frames.
 *
 * @param opacity The opacity of the overlay.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this is production.
 */
- (void)showMaskPreview:(CGFloat)opacity;

/**
 * Removes the overlay that shows replay masking.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this is production.
 */
- (void)hideMaskPreview;

@end

NS_ASSUME_NONNULL_END

#endif
