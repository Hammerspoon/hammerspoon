#import "SentryFramesTracker.h"
#import "SentryCompiler.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"
#import "SentryTracer.h"
#import <SentryScreenFrames.h>
#include <stdatomic.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** A mutable version of @c SentryFrameInfoTimeSeries so we can accumulate results. */
typedef NSMutableArray<NSDictionary<NSString *, NSNumber *> *> SentryMutableFrameInfoTimeSeries;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

static CFTimeInterval const SentryFrozenFrameThreshold = 0.7;
static CFTimeInterval const SentryPreviousFrameInitialValue = -1;

/**
 * Relaxed memoring ordering is typical for incrementing counters. This operation only requires
 * atomicity but not ordering or synchronization.
 */
static memory_order const SentryFramesMemoryOrder = memory_order_relaxed;

@interface
SentryFramesTracker ()

@property (nonatomic, strong, readonly) SentryDisplayLinkWrapper *displayLinkWrapper;
@property (nonatomic, assign) CFTimeInterval previousFrameTimestamp;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frozenFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *slowFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frameRateTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

@implementation SentryFramesTracker {

    /**
     * With 32 bit we can track frames with 120 fps for around 414 days (2^32 / (120* 60 * 60 *
     * 24)).
     */
    atomic_uint_fast32_t _totalFrames;
    atomic_uint_fast32_t _slowFrames;
    atomic_uint_fast32_t _frozenFrames;
}

+ (instancetype)sharedInstance
{
    static SentryFramesTracker *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance =
            [[self alloc] initWithDisplayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]];
    });
    return sharedInstance;
}

/** Internal constructor for testing */
- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
{
    if (self = [super init]) {
        _isRunning = NO;
        _displayLinkWrapper = displayLinkWrapper;
        [self resetFrames];
    }
    return self;
}

/** Internal for testing */
- (void)setDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
{
    _displayLinkWrapper = displayLinkWrapper;
}

/** Internal for testing */
- (void)resetFrames
{
    atomic_store_explicit(&_totalFrames, 0, SentryFramesMemoryOrder);
    atomic_store_explicit(&_frozenFrames, 0, SentryFramesMemoryOrder);
    atomic_store_explicit(&_slowFrames, 0, SentryFramesMemoryOrder);

    self.previousFrameTimestamp = SentryPreviousFrameInitialValue;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    [self resetProfilingTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)resetProfilingTimestamps
{
    self.frozenFrameTimestamps = [SentryMutableFrameInfoTimeSeries array];
    self.slowFrameTimestamps = [SentryMutableFrameInfoTimeSeries array];
    self.frameRateTimestamps = [SentryMutableFrameInfoTimeSeries array];
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)start
{
    _isRunning = YES;
    [_displayLinkWrapper linkWithTarget:self selector:@selector(displayLinkCallback)];
}

- (void)displayLinkCallback
{
    CFTimeInterval thisFrameTimestamp = self.displayLinkWrapper.timestamp;

    if (self.previousFrameTimestamp == SentryPreviousFrameInitialValue) {
        self.previousFrameTimestamp = thisFrameTimestamp;
        return;
    }

    // Calculate the actual frame rate as pointed out by the Apple docs:
    // https://developer.apple.com/documentation/quartzcore/cadisplaylink?language=objc The actual
    // frame rate can change at any time by setting preferredFramesPerSecond or due to ProMotion
    // display, low power mode, critical thermal state, and accessibility settings. Therefore we
    // need to check the frame rate for every callback.
    // targetTimestamp is only available on iOS 10.0 and tvOS 10.0 and above. We use a fallback of
    // 60 fps.
    double actualFramesPerSecond = 60.0;
    if (UNLIKELY((self.displayLinkWrapper.targetTimestamp == self.displayLinkWrapper.timestamp))) {
        actualFramesPerSecond = 60.0;
    } else {
        actualFramesPerSecond
            = 1 / (self.displayLinkWrapper.targetTimestamp - self.displayLinkWrapper.timestamp);
    }

#    if SENTRY_TARGET_PROFILING_SUPPORTED
#        if defined(TEST) || defined(TESTCI)
    BOOL shouldRecordFrameRates = YES;
#        else
    BOOL shouldRecordFrameRates = [SentryProfiler isRunning];
#        endif // defined(TEST) || defined(TESTCI)
    BOOL hasNoFrameRatesYet = self.frameRateTimestamps.count == 0;
    BOOL frameRateSignificantlyChanged
        = fabs(self.frameRateTimestamps.lastObject[@"frame_rate"].doubleValue
              - actualFramesPerSecond)
        > 1e-10f; // these may be a small fraction off of a whole number of frames per second, so
                  // allow some small epsilon difference
    BOOL shouldRecordNewFrameRate
        = shouldRecordFrameRates && (hasNoFrameRatesYet || frameRateSignificantlyChanged);
    if (shouldRecordNewFrameRate) {
        [self.frameRateTimestamps addObject:@{
            @"timestamp" : @(self.displayLinkWrapper.timestamp),
            @"frame_rate" : @(actualFramesPerSecond),
        }];
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

    // Most frames take just a few microseconds longer than the optimal calculated duration.
    // Therefore we subtract one, because otherwise almost all frames would be slow.
    CFTimeInterval slowFrameThreshold = 1 / (actualFramesPerSecond - 1);

    CFTimeInterval frameDuration = thisFrameTimestamp - self.previousFrameTimestamp;

    if (frameDuration > slowFrameThreshold && frameDuration <= SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_slowFrames, 1, SentryFramesMemoryOrder);
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        [self recordTimestampStart:@(self.previousFrameTimestamp)
                               end:@(thisFrameTimestamp)
                             array:self.slowFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    } else if (frameDuration > SentryFrozenFrameThreshold) {
        atomic_fetch_add_explicit(&_frozenFrames, 1, SentryFramesMemoryOrder);
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        [self recordTimestampStart:@(self.previousFrameTimestamp)
                               end:@(thisFrameTimestamp)
                             array:self.frozenFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }

    atomic_fetch_add_explicit(&_totalFrames, 1, SentryFramesMemoryOrder);
    self.previousFrameTimestamp = thisFrameTimestamp;
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)recordTimestampStart:(NSNumber *)start end:(NSNumber *)end array:(NSMutableArray *)array
{
    BOOL shouldRecord = [SentryProfiler isRunning];
#        if defined(TEST) || defined(TESTCI)
    shouldRecord = YES;
#        endif
    if (shouldRecord) {
        [array addObject:@{ @"start_timestamp" : start, @"end_timestamp" : end }];
    }
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (SentryScreenFrames *)currentFrames
{
    NSUInteger total = atomic_load_explicit(&_totalFrames, SentryFramesMemoryOrder);
    NSUInteger slow = atomic_load_explicit(&_slowFrames, SentryFramesMemoryOrder);
    NSUInteger frozen = atomic_load_explicit(&_frozenFrames, SentryFramesMemoryOrder);

#    if SENTRY_TARGET_PROFILING_SUPPORTED
    return [[SentryScreenFrames alloc] initWithTotal:total
                                              frozen:frozen
                                                slow:slow
                                 slowFrameTimestamps:self.slowFrameTimestamps
                               frozenFrameTimestamps:self.frozenFrameTimestamps
                                 frameRateTimestamps:self.frameRateTimestamps];
#    else
    return [[SentryScreenFrames alloc] initWithTotal:total frozen:frozen slow:slow];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (void)stop
{
    _isRunning = NO;
    [self.displayLinkWrapper invalidate];
}

@end

#endif
