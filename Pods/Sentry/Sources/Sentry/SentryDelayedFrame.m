#import "SentryDelayedFrame.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDelayedFrame

- (instancetype)initWithStartTimestamp:(uint64_t)startSystemTimestamp
                      expectedDuration:(CFTimeInterval)expectedDuration
                        actualDuration:(CFTimeInterval)actualDuration
{
    if (self = [super init]) {
        _startSystemTimestamp = startSystemTimestamp;
        _expectedDuration = expectedDuration;
        _actualDuration = actualDuration;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
