#import "SentryTimeToDisplayTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryFramesTracker.h"
#    import "SentryLog.h"
#    import "SentryMeasurementValue.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfilingConditionals.h"
#    import "SentrySDK+Private.h"
#    import "SentrySpan.h"
#    import "SentrySpanContext.h"
#    import "SentrySpanId.h"
#    import "SentrySpanOperations.h"
#    import "SentrySwift.h"
#    import "SentryTraceOrigins.h"
#    import "SentryTracer.h"

#    import <UIKit/UIKit.h>

#    if SENTRY_TARGET_PROFILING_SUPPORTED
#        import "SentryLaunchProfiling.h"
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@interface
SentryTimeToDisplayTracker () <SentryFramesTrackerListener>

@property (nonatomic, weak) SentrySpan *initialDisplaySpan;
@property (nonatomic, weak) SentrySpan *fullDisplaySpan;
@property (nonatomic, strong, readonly) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

@implementation SentryTimeToDisplayTracker {
    BOOL _waitForFullDisplay;
    BOOL _initialDisplayReported;
    BOOL _fullyDisplayedReported;
    NSString *_controllerName;
}

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitForFullDisplay
             dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        _controllerName = [SwiftDescriptor getObjectClassName:controller];
        _waitForFullDisplay = waitForFullDisplay;
        _dispatchQueueWrapper = dispatchQueueWrapper;
        _initialDisplayReported = NO;
        _fullyDisplayedReported = NO;
    }
    return self;
}

- (void)startForTracer:(SentryTracer *)tracer
{
    SENTRY_LOG_DEBUG(@"Starting initial display span");
    self.initialDisplaySpan = [tracer
        startChildWithOperation:SentrySpanOperationUILoadInitialDisplay
                    description:[NSString stringWithFormat:@"%@ initial display", _controllerName]];
    self.initialDisplaySpan.origin = SentryTraceOriginAutoUITimeToDisplay;

    if (self.waitForFullDisplay) {
        SENTRY_LOG_DEBUG(@"Starting full display span");
        self.fullDisplaySpan =
            [tracer startChildWithOperation:SentrySpanOperationUILoadFullDisplay
                                description:[NSString stringWithFormat:@"%@ full display",
                                                      _controllerName]];
        self.fullDisplaySpan.origin = SentryTraceOriginManualUITimeToDisplay;

        // By concept TTID and TTFD spans should have the same beginning,
        // which also should be the same of the transaction starting.
        self.fullDisplaySpan.startTimestamp = tracer.startTimestamp;
    }

    self.initialDisplaySpan.startTimestamp = tracer.startTimestamp;

    [SentryDependencyContainer.sharedInstance.framesTracker addListener:self];

    [tracer setShouldIgnoreWaitForChildrenCallback:^(id<SentrySpan> span) {
        if (span.origin == SentryTraceOriginAutoUITimeToDisplay) {
            return YES;
        } else {
            return NO;
        }
    }];
    [tracer setFinishCallback:^(SentryTracer *_tracer) {
        [SentryDependencyContainer.sharedInstance.framesTracker removeListener:self];

        // The tracer finishes when the screen is fully displayed. Therefore, we must also finish
        // the TTID span.
        if (self.initialDisplaySpan.isFinished == NO) {
            [self.initialDisplaySpan finish];
        }

        // If the start time of the tracer changes, which is the case for app start transactions, we
        // also need to adapt the start time of our spans.
        self.initialDisplaySpan.startTimestamp = _tracer.startTimestamp;
        [self addTimeToDisplayMeasurement:self.initialDisplaySpan name:@"time_to_initial_display"];

        if (self.fullDisplaySpan == nil) {
            return;
        }

        self.fullDisplaySpan.startTimestamp = _tracer.startTimestamp;
        [self addTimeToDisplayMeasurement:self.fullDisplaySpan name:@"time_to_full_display"];

        if (self.fullDisplaySpan.status != kSentrySpanStatusDeadlineExceeded) {
            return;
        }

        self.fullDisplaySpan.timestamp = self.initialDisplaySpan.timestamp;
        self.fullDisplaySpan.spanDescription = [NSString
            stringWithFormat:@"%@ - Deadline Exceeded", self.fullDisplaySpan.spanDescription];
        [self addTimeToDisplayMeasurement:self.fullDisplaySpan name:@"time_to_full_display"];
    }];
}

- (void)reportInitialDisplay
{
    _initialDisplayReported = YES;
}

- (void)reportFullyDisplayed
{
    // All other accesses to _fullyDisplayedReported run on the main thread.
    // To avoid using locks, we execute this on the main queue instead.
    [_dispatchQueueWrapper dispatchAsyncOnMainQueue:^{ self->_fullyDisplayedReported = YES; }];
}

- (void)framesTrackerHasNewFrame:(NSDate *)newFrameDate
{
    // The purpose of TTID and TTFD is to measure how long
    // takes to the content of the screen to change.
    // Thats why we need to wait for the next frame to be drawn.
    if (_initialDisplayReported && self.initialDisplaySpan.isFinished == NO) {
        SENTRY_LOG_DEBUG(@"Finishing initial display span");
        self.initialDisplaySpan.timestamp = newFrameDate;
        [self.initialDisplaySpan finish];
        if (!_waitForFullDisplay) {
            [SentryDependencyContainer.sharedInstance.framesTracker removeListener:self];
#    if SENTRY_TARGET_PROFILING_SUPPORTED
            if (![SentrySDK.options isContinuousProfilingEnabled]) {
                sentry_stopAndDiscardLaunchProfileTracer();
            }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
        }
    }
    if (_waitForFullDisplay && _fullyDisplayedReported && self.fullDisplaySpan.isFinished == NO
        && self.initialDisplaySpan.isFinished == YES) {
        SENTRY_LOG_DEBUG(@"Finishing full display span");
        self.fullDisplaySpan.timestamp = newFrameDate;
        [self.fullDisplaySpan finish];
#    if SENTRY_TARGET_PROFILING_SUPPORTED
        if (![SentrySDK.options isContinuousProfilingEnabled]) {
            sentry_stopAndDiscardLaunchProfileTracer();
        }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }

    if (self.initialDisplaySpan.isFinished == YES && self.fullDisplaySpan.isFinished == YES) {
        [SentryDependencyContainer.sharedInstance.framesTracker removeListener:self];
    }
}

- (void)addTimeToDisplayMeasurement:(SentrySpan *)span name:(NSString *)name
{
    NSTimeInterval duration = [span.timestamp timeIntervalSinceDate:span.startTimestamp] * 1000;
    [span setMeasurement:name value:@(duration) unit:SentryMeasurementUnitDuration.millisecond];
}

@end

#endif // SENTRY_HAS_UIKIT
