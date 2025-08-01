#import "SentryTimeToDisplayTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDependencyContainer.h"
#    import "SentryFramesTracker.h"
#    import "SentryLogC.h"
#    import "SentryMeasurementValue.h"
#    import "SentryOptions+Private.h"
#    import "SentryProfilingConditionals.h"
#    import "SentrySDK+Private.h"
#    import "SentrySpan.h"
#    import "SentrySpanContext.h"
#    import "SentrySpanId.h"
#    import "SentrySpanOperation.h"
#    import "SentrySwift.h"
#    import "SentryTraceOrigin.h"
#    import "SentryTracer.h"

#    import <UIKit/UIKit.h>

#    if SENTRY_TARGET_PROFILING_SUPPORTED
#        import "SentryLaunchProfiling.h"
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@interface SentryTimeToDisplayTracker () <SentryFramesTrackerListener>

@property (nonatomic, weak) SentrySpan *initialDisplaySpan;
@property (nonatomic, weak) SentrySpan *fullDisplaySpan;
@property (nonatomic, strong, readonly) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

@implementation SentryTimeToDisplayTracker {
    BOOL _waitForFullDisplay;
    BOOL _initialDisplayReported;
    BOOL _fullyDisplayedReported;
    NSString *_name;
}

- (instancetype)initWithName:(NSString *)name
          waitForFullDisplay:(BOOL)waitForFullDisplay
        dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        _name = name;
        _waitForFullDisplay = waitForFullDisplay;
        _dispatchQueueWrapper = dispatchQueueWrapper;
        _initialDisplayReported = NO;
        _fullyDisplayedReported = NO;
    }
    return self;
}

- (BOOL)startForTracer:(SentryTracer *)tracer
{
    if (SentryDependencyContainer.sharedInstance.framesTracker.isRunning == NO) {
        SENTRY_LOG_DEBUG(@"Skipping TTID/TTFD spans, because can't report them correctly when the "
                         @"frames tracker isn't running.");
        return NO;
    }

    SENTRY_LOG_DEBUG(@"Starting initial display span");
    self.initialDisplaySpan =
        [tracer startChildWithOperation:SentrySpanOperationUiLoadInitialDisplay
                            description:[NSString stringWithFormat:@"%@ initial display", _name]];
    self.initialDisplaySpan.origin = SentryTraceOriginAutoUITimeToDisplay;

    if (self.waitForFullDisplay) {
        SENTRY_LOG_DEBUG(@"Starting full display span");
        self.fullDisplaySpan =
            [tracer startChildWithOperation:SentrySpanOperationUiLoadFullDisplay
                                description:[NSString stringWithFormat:@"%@ full display", _name]];
        self.fullDisplaySpan.origin = SentryTraceOriginManualUITimeToDisplay;

        // By concept TTID and TTFD spans should have the same beginning,
        // which also should be the same of the transaction starting.
        self.fullDisplaySpan.startTimestamp = tracer.startTimestamp;
    }

    self.initialDisplaySpan.startTimestamp = tracer.startTimestamp;

    [SentryDependencyContainer.sharedInstance.framesTracker addListener:self];

    [tracer setShouldIgnoreWaitForChildrenCallback:^(id<SentrySpan> span) {
        if ([span.origin isEqualToString:SentryTraceOriginAutoUITimeToDisplay]) {
            return YES;
        }

        return NO;
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

    return YES;
}

- (void)reportInitialDisplay
{
    SENTRY_LOG_DEBUG(@"Reporting initial display for %@", _name);
    _initialDisplayReported = YES;
}

- (void)reportFullyDisplayed
{
    SENTRY_LOG_DEBUG(@"Reporting full display for %@", _name);
    // All other accesses to _fullyDisplayedReported run on the main thread.
    // To avoid using locks, we execute this on the main queue instead.
    [_dispatchQueueWrapper dispatchAsyncOnMainQueue:^{ self->_fullyDisplayedReported = YES; }];
}

- (void)finishSpansIfNotFinished
{
    [SentryDependencyContainer.sharedInstance.framesTracker removeListener:self];

    if (self.initialDisplaySpan.isFinished == NO) {
        [self.initialDisplaySpan finish];
    }

    if (self.fullDisplaySpan.isFinished == NO) {
        if (_fullyDisplayedReported) {
            SENTRY_LOG_DEBUG(
                @"SentrySDK.reportFullyDisplayed() was called but didn't receive a new frame to "
                @"finish the TTFD span. Finishing the full display span so the SDK can start a new "
                @"time to display tracker.");
            [self.fullDisplaySpan finish];
            return;
        }

        SENTRY_LOG_WARN(@"You didn't call SentrySDK.reportFullyDisplayed() for UIViewController: "
                        @"%@. Finishing full display span with status: %@.",
            _name, nameForSentrySpanStatus(kSentrySpanStatusDeadlineExceeded));

        [self.fullDisplaySpan finishWithStatus:kSentrySpanStatusDeadlineExceeded];
    }
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
            if ([SentrySDK.options isProfilingCorrelatedToTraces]) {
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
        if ([SentrySDK.options isProfilingCorrelatedToTraces]) {
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
