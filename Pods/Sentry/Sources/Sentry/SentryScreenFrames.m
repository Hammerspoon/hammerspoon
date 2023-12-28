#import <SentryScreenFrames.h>

#if SENTRY_UIKIT_AVAILABLE
#    import "SentryInternalDefines.h"

@implementation SentryScreenFrames

- (instancetype)initWithTotal:(NSUInteger)total frozen:(NSUInteger)frozen slow:(NSUInteger)slow
{
#    if SENTRY_HAS_UIKIT
#        if SENTRY_TARGET_PROFILING_SUPPORTED
    return [self initWithTotal:total
                        frozen:frozen
                          slow:slow
           slowFrameTimestamps:@[]
         frozenFrameTimestamps:@[]
           frameRateTimestamps:@[]];
#        else
    if (self = [super init]) {
        _total = total;
        _slow = slow;
        _frozen = frozen;
    }

    return self;
#        endif // SENTRY_TARGET_PROFILING_SUPPORTED
#    else
    SENTRY_GRACEFUL_FATAL(
        @"SentryScreenFrames only works with UIKit enabled. Ensure you're using the "
        @"right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (instancetype)initWithTotal:(NSUInteger)total
                       frozen:(NSUInteger)frozen
                         slow:(NSUInteger)slow
          slowFrameTimestamps:(SentryFrameInfoTimeSeries *)slowFrameTimestamps
        frozenFrameTimestamps:(SentryFrameInfoTimeSeries *)frozenFrameTimestamps
          frameRateTimestamps:(SentryFrameInfoTimeSeries *)frameRateTimestamps
{
#        if SENTRY_HAS_UIKIT
    if (self = [super init]) {
        _total = total;
        _slow = slow;
        _frozen = frozen;
        _slowFrameTimestamps = slowFrameTimestamps;
        _frozenFrameTimestamps = frozenFrameTimestamps;
        _frameRateTimestamps = frameRateTimestamps;
    }

    return self;
#        else
    SENTRY_GRACEFUL_FATAL(
        @"SentryScreenFrames only works with UIKit enabled. Ensure you're using the "
        @"right configuration of Sentry that links UIKit.");
    return nil;
#        endif // SENTRY_HAS_UIKIT
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
#        if SENTRY_HAS_UIKIT
    return [[SentryScreenFrames allocWithZone:zone] initWithTotal:_total
                                                           frozen:_frozen
                                                             slow:_slow
                                              slowFrameTimestamps:[_slowFrameTimestamps copy]
                                            frozenFrameTimestamps:[_frozenFrameTimestamps copy]
                                              frameRateTimestamps:[_frameRateTimestamps copy]];
#        else
    SENTRY_GRACEFUL_FATAL(
        @"SentryScreenFrames only works with UIKit enabled. Ensure you're using the "
        @"right configuration of Sentry that links UIKit.");
    return nil;
#        endif // SENTRY_HAS_UIKIT
}

#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

#endif // SENTRY_UIKIT_AVAILABLE
