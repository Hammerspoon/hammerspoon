#import "PrivatesHeader.h"

#if SENTRY_UIKIT_AVAILABLE

NS_ASSUME_NONNULL_BEGIN

/** An array of dictionaries that each contain a start and end timestamp for a rendered frame. */
#    if SENTRY_TARGET_PROFILING_SUPPORTED
typedef NSArray<NSDictionary<NSString *, NSNumber *> *> SentryFrameInfoTimeSeries;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

/**
 * @warning This feature is not available in @c DebugWithoutUIKit and @c ReleaseWithoutUIKit
 * configurations even when targeting iOS or tvOS platforms.
 */
@interface SentryScreenFrames : NSObject
#    if SENTRY_TARGET_PROFILING_SUPPORTED
                                <NSCopying>
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
SENTRY_NO_INIT

- (instancetype)initWithTotal:(NSUInteger)total frozen:(NSUInteger)frozen slow:(NSUInteger)slow;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (instancetype)initWithTotal:(NSUInteger)total
                       frozen:(NSUInteger)frozen
                         slow:(NSUInteger)slow
          slowFrameTimestamps:(SentryFrameInfoTimeSeries *)slowFrameTimestamps
        frozenFrameTimestamps:(SentryFrameInfoTimeSeries *)frozenFrameTimestamps
          frameRateTimestamps:(SentryFrameInfoTimeSeries *)frameRateTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@property (nonatomic, assign, readonly) NSUInteger total;
@property (nonatomic, assign, readonly) NSUInteger frozen;
@property (nonatomic, assign, readonly) NSUInteger slow;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Array of dictionaries describing slow frames' timestamps. Each dictionary has a start and end
 * timestamp for every such frame, keyed under @c start_timestamp and @c end_timestamp.
 */
@property (nonatomic, copy, readonly) SentryFrameInfoTimeSeries *slowFrameTimestamps;

/**
 * Array of dictionaries describing frozen frames' timestamps. Each dictionary has a start and end
 * timestamp for every such frame, keyed under @c start_timestamp and @c end_timestamp.
 */
@property (nonatomic, copy, readonly) SentryFrameInfoTimeSeries *frozenFrameTimestamps;

/**
 * Array of dictionaries describing the screen refresh rate at all points in time that it changes,
 * which can happen when modern devices e.g. go into low power mode. Each dictionary contains keys
 * @c timestamp and @c frame_rate.
 */
@property (nonatomic, copy, readonly) SentryFrameInfoTimeSeries *frameRateTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_UIKIT_AVAILABLE
