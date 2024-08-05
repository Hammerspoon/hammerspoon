#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryDelayedFrame : NSObject
SENTRY_NO_INIT

- (instancetype)initWithStartTimestamp:(uint64_t)startSystemTimestamp
                      expectedDuration:(CFTimeInterval)expectedDuration
                        actualDuration:(CFTimeInterval)actualDuration;

@property (nonatomic, readonly) uint64_t startSystemTimestamp;
@property (nonatomic, readonly) CFTimeInterval expectedDuration;
@property (nonatomic, readonly) CFTimeInterval actualDuration;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
