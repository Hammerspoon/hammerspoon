#import "SentryFramesTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCompiler.h"
#    import "SentryCurrentDateProvider.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryLog.h"
#    import "SentryProfiler.h"
#    import "SentryProfilingConditionals.h"
#    import "SentryTime.h"
#    import "SentryTracer.h"
#    import <SentryScreenFrames.h>
#    include <stdatomic.h>

#    if SENTRY_TARGET_PROFILING_SUPPORTED
/** A mutable version of @c SentryFrameInfoTimeSeries so we can accumulate results. */
typedef NSMutableArray<NSDictionary<NSString *, NSNumber *> *> SentryMutableFrameInfoTimeSeries;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

static CFTimeInterval const SentryFrozenFrameThreshold = 0.7;
static CFTimeInterval const SentryPreviousFrameInitialValue = -1;

@interface
SentryFramesTracker ()

@property (nonatomic, strong, readonly) SentryDisplayLinkWrapper *displayLinkWrapper;
@property (nonatomic, assign) CFTimeInterval previousFrameTimestamp;
@property (nonatomic) uint64_t previousFrameSystemTimestamp;
@property (nonatomic, strong) NSHashTable<id<SentryFramesTrackerListener>> *listeners;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frozenFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *slowFrameTimestamps;
@property (nonatomic, readwrite) SentryMutableFrameInfoTimeSeries *frameRateTimestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

CFTimeInterval
slowFrameThreshold(uint64_t actualFramesPerSecond)
{
    // Most frames take just a few microseconds longer than the optimal calculated duration.
    // Therefore we subtract one, because otherwise almost all frames would be slow.
    return 1.0 / (actualFramesPerSecond - 1.0);
}

@implementation SentryFramesTracker {
    unsigned int _totalFrames;
    unsigned int _slowFrames;
    unsigned int _frozenFrames;
}

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper
{
    if (self = [super init]) {
        _isRunning = NO;
        _displayLinkWrapper = displayLinkWrapper;
        _listeners = [NSHashTable weakObjectsHashTable];
        [self resetFrames];
        SENTRY_LOG_DEBUG(@"Initialized frame tracker %@", self);
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
    _totalFrames = 0;
    _frozenFrames = 0;
    _slowFrames = 0;

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
    if (_isRunning) {
        return;
    }

    _isRunning = YES;

    [_displayLinkWrapper linkWithTarget:self selector:@selector(displayLinkCallback)];
}

- (void)displayLinkCallback
{
    CFTimeInterval thisFrameTimestamp = self.displayLinkWrapper.timestamp;
    uint64_t thisFrameSystemTimestamp
        = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;

    if (self.previousFrameTimestamp == SentryPreviousFrameInitialValue) {
        self.previousFrameTimestamp = thisFrameTimestamp;
        self.previousFrameSystemTimestamp = thisFrameSystemTimestamp;
        [self reportNewFrame];
        return;
    }

    // Calculate the actual frame rate as pointed out by the Apple docs:
    // https://developer.apple.com/documentation/quartzcore/cadisplaylink?language=objc The actual
    // frame rate can change at any time by setting preferredFramesPerSecond or due to ProMotion
    // display, low power mode, critical thermal state, and accessibility settings. Therefore we
    // need to check the frame rate for every callback.
    // targetTimestamp is only available on iOS 10.0 and tvOS 10.0 and above. We use a fallback of
    // 60 fps.
    uint64_t currentFrameRate = 60;
    if (UNLIKELY((self.displayLinkWrapper.targetTimestamp == self.displayLinkWrapper.timestamp))) {
        currentFrameRate = 60;
    } else {
        currentFrameRate = (uint64_t)round(
            (1 / (self.displayLinkWrapper.targetTimestamp - self.displayLinkWrapper.timestamp)));
    }

#    if SENTRY_TARGET_PROFILING_SUPPORTED
    if ([SentryProfiler isCurrentlyProfiling]) {
        BOOL hasNoFrameRatesYet = self.frameRateTimestamps.count == 0;
        uint64_t previousFrameRate
            = self.frameRateTimestamps.lastObject[@"value"].unsignedLongLongValue;
        BOOL frameRateChanged = previousFrameRate != currentFrameRate;
        BOOL shouldRecordNewFrameRate = hasNoFrameRatesYet || frameRateChanged;
        if (shouldRecordNewFrameRate) {
            SENTRY_LOG_DEBUG(@"Recording new frame rate at %llu.", thisFrameSystemTimestamp);
            [self recordTimestamp:thisFrameSystemTimestamp
                            value:@(currentFrameRate)
                            array:self.frameRateTimestamps];
        }
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

    CFTimeInterval frameDuration = thisFrameTimestamp - self.previousFrameTimestamp;

    if (frameDuration > slowFrameThreshold(currentFrameRate)
        && frameDuration <= SentryFrozenFrameThreshold) {
        _slowFrames++;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        SENTRY_LOG_DEBUG(@"Capturing slow frame starting at %llu (frame tracker: %@).",
            thisFrameSystemTimestamp, self);
        [self recordTimestamp:thisFrameSystemTimestamp
                        value:@(thisFrameSystemTimestamp - self.previousFrameSystemTimestamp)
                        array:self.slowFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    } else if (frameDuration > SentryFrozenFrameThreshold) {
        _frozenFrames++;
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        SENTRY_LOG_DEBUG(@"Capturing frozen frame starting at %llu.", thisFrameSystemTimestamp);
        [self recordTimestamp:thisFrameSystemTimestamp
                        value:@(thisFrameSystemTimestamp - self.previousFrameSystemTimestamp)
                        array:self.frozenFrameTimestamps];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }
    _totalFrames++;
    self.previousFrameTimestamp = thisFrameTimestamp;
    self.previousFrameSystemTimestamp = thisFrameSystemTimestamp;
    [self reportNewFrame];
}

- (void)reportNewFrame
{
    NSArray *localListeners;
    @synchronized(self.listeners) {
        localListeners = [self.listeners allObjects];
    }

    for (id<SentryFramesTrackerListener> listener in localListeners) {
        [listener framesTrackerHasNewFrame];
    }
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)recordTimestamp:(uint64_t)timestamp value:(NSNumber *)value array:(NSMutableArray *)array
{
    BOOL shouldRecord = [SentryProfiler isCurrentlyProfiling];
#        if defined(TEST) || defined(TESTCI)
    shouldRecord = YES;
#        endif // defined(TEST) || defined(TESTCI)
    if (shouldRecord) {
        [array addObject:@{ @"timestamp" : @(timestamp), @"value" : value }];
    }
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (SentryScreenFrames *)currentFrames
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    return [[SentryScreenFrames alloc] initWithTotal:_totalFrames
                                              frozen:_frozenFrames
                                                slow:_slowFrames
                                 slowFrameTimestamps:self.slowFrameTimestamps
                               frozenFrameTimestamps:self.frozenFrameTimestamps
                                 frameRateTimestamps:self.frameRateTimestamps];
#    else
    return [[SentryScreenFrames alloc] initWithTotal:_totalFrames
                                              frozen:_frozenFrames
                                                slow:_slowFrames];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (void)addListener:(id<SentryFramesTrackerListener>)listener
{

    @synchronized(self.listeners) {
        [self.listeners addObject:listener];
    }
}

- (void)removeListener:(id<SentryFramesTrackerListener>)listener
{
    @synchronized(self.listeners) {
        [self.listeners removeObject:listener];
    }
}

- (void)stop
{
    _isRunning = NO;
    [self.displayLinkWrapper invalidate];
}

- (void)dealloc
{
    [self stop];
}

@end

#endif // SENTRY_HAS_UIKIT
