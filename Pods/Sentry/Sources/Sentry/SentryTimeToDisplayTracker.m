#import "SentryTimeToDisplayTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryCurrentDateProvider.h"
#    import "SentryDependencyContainer.h"
#    import "SentryFramesTracker.h"
#    import "SentryMeasurementValue.h"
#    import "SentrySpan.h"
#    import "SentrySpanContext.h"
#    import "SentrySpanId.h"
#    import "SentrySpanOperations.h"
#    import "SentrySwift.h"
#    import "SentryTraceOrigins.h"
#    import "SentryTracer.h"

#    import <UIKit/UIKit.h>

@interface
SentryTimeToDisplayTracker () <SentryFramesTrackerListener>

@property (nonatomic, weak) SentrySpan *initialDisplaySpan;
@property (nonatomic, weak) SentrySpan *fullDisplaySpan;

@end

@implementation SentryTimeToDisplayTracker {
    BOOL _waitForFullDisplay;
    BOOL _isReadyToDisplay;
    BOOL _fullyDisplayedReported;
    NSString *_controllerName;
}

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitForFullDisplay
{
    if (self = [super init]) {
        _controllerName = [SwiftDescriptor getObjectClassName:controller];
        _waitForFullDisplay = waitForFullDisplay;

        _isReadyToDisplay = NO;
        _fullyDisplayedReported = NO;
    }
    return self;
}

- (void)startForTracer:(SentryTracer *)tracer
{
    self.initialDisplaySpan = [tracer
        startChildWithOperation:SentrySpanOperationUILoadInitialDisplay
                    description:[NSString stringWithFormat:@"%@ initial display", _controllerName]];
    self.initialDisplaySpan.origin = SentryTraceOriginAutoUITimeToDisplay;

    if (self.waitForFullDisplay) {
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
    [tracer setFinishCallback:^(
        SentryTracer *_tracer) { [self trimTTFDIdNecessaryForTracer:_tracer]; }];
}

- (void)reportReadyToDisplay
{
    _isReadyToDisplay = YES;
}

- (void)reportFullyDisplayed
{
    _fullyDisplayedReported = YES;
    if (self.waitForFullDisplay && _isReadyToDisplay) {
        // We need the timestamp to be able to calculate the duration
        // but we can't finish first and add measure later because
        // finishing the span may trigger the tracer finishInternal.
        self.fullDisplaySpan.timestamp =
            [SentryDependencyContainer.sharedInstance.dateProvider date];
        [self addTimeToDisplayMeasurement:self.fullDisplaySpan name:@"time_to_full_display"];
        [self.fullDisplaySpan finish];
    }
}

- (void)addTimeToDisplayMeasurement:(SentrySpan *)span name:(NSString *)name
{
    NSTimeInterval duration = [span.timestamp timeIntervalSinceDate:span.startTimestamp] * 1000;
    [span setMeasurement:name value:@(duration) unit:SentryMeasurementUnitDuration.millisecond];
}

- (void)framesTrackerHasNewFrame
{
    NSDate *finishTime = [SentryDependencyContainer.sharedInstance.dateProvider date];

    // The purpose of TTID and TTFD is to measure how long
    // takes to the content of the screen to change.
    // Thats why we need to wait for the next frame to be drawn.
    if (_isReadyToDisplay && self.initialDisplaySpan.isFinished == NO) {
        self.initialDisplaySpan.timestamp = finishTime;

        [self addTimeToDisplayMeasurement:self.initialDisplaySpan name:@"time_to_initial_display"];

        [self.initialDisplaySpan finish];
        [SentryDependencyContainer.sharedInstance.framesTracker removeListener:self];
    }
    if (_waitForFullDisplay && _fullyDisplayedReported && self.fullDisplaySpan.isFinished == NO) {
        self.fullDisplaySpan.timestamp = finishTime;

        [self addTimeToDisplayMeasurement:self.initialDisplaySpan name:@"time_to_full_display"];

        [self.fullDisplaySpan finish];
    }
}

- (void)trimTTFDIdNecessaryForTracer:(SentryTracer *)tracer
{
    if (self.fullDisplaySpan.status != kSentrySpanStatusDeadlineExceeded) {
        return;
    }

    self.fullDisplaySpan.timestamp = self.initialDisplaySpan.timestamp;
    self.fullDisplaySpan.spanDescription =
        [NSString stringWithFormat:@"%@ - Deadline Exceeded", self.fullDisplaySpan.spanDescription];
}

@end

#endif // SENTRY_HAS_UIKIT
