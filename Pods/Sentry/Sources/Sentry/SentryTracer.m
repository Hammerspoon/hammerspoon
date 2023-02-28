#import "SentryTracer.h"
#import "NSDictionary+SentrySanitize.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryAppStartMeasurement.h"
#import "SentryClient.h"
#import "SentryCurrentDate.h"
#import "SentryDebugImageProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryFramesTracker.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryNSTimerWrapper.h"
#import "SentryNoOpSpan.h"
#import "SentryProfiler.h"
#import "SentryProfilesSampler.h"
#import "SentryProfilingConditionals.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTime.h"
#import "SentryTraceContext.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"
#import "SentryUIViewControllerPerformanceTracker.h"
#import <NSMutableDictionary+Sentry.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryMeasurementValue.h>
#import <SentryScreenFrames.h>
#import <SentrySpanOperations.h>

NS_ASSUME_NONNULL_BEGIN

static const void *spanTimestampObserver = &spanTimestampObserver;

/**
 * The maximum amount of seconds the app start measurement end time and the start time of the
 * transaction are allowed to be apart.
 */
static const NSTimeInterval SENTRY_APP_START_MEASUREMENT_DIFFERENCE = 5.0;
static const NSTimeInterval SENTRY_AUTO_TRANSACTION_MAX_DURATION = 500.0;
static const NSTimeInterval SENTRY_AUTO_TRANSACTION_DEADLINE = 30.0;

@interface
SentryTracer ()

@property (nonatomic, strong) SentryHub *hub;
@property (nonatomic) SentrySpanStatus finishStatus;
/** This property is different from isFinished. While isFinished states if the tracer is actually
 * finished, this property tells you if finish was called on the tracer. Calling finish doesn't
 * necessarily lead to finishing the tracer, because it could still wait for child spans to finish
 * if waitForChildren is <code>YES</code>. */
@property (nonatomic) BOOL wasFinishCalled;
@property (nonatomic) NSTimeInterval idleTimeout;
@property (nonatomic, nullable, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, nullable, strong) SentryNSTimerWrapper *timerWrapper;
@property (nonatomic, nullable, strong) NSTimer *deadlineTimer;

@end

@implementation SentryTracer {
    /** Wether the tracer should wait for child spans to finish before finishing itself. */
    BOOL _waitForChildren;
    SentryTraceContext *_traceContext;
    SentryAppStartMeasurement *appStartMeasurement;
    NSMutableDictionary<NSString *, SentryMeasurementValue *> *_measurements;
    dispatch_block_t _idleTimeoutBlock;
    NSMutableArray<id<SentrySpan>> *_children;

#if SENTRY_HAS_UIKIT
    BOOL _startTimeChanged;

    NSUInteger initTotalFrames;
    NSUInteger initSlowFrames;
    NSUInteger initFrozenFrames;
#endif
}

static NSObject *appStartMeasurementLock;
static BOOL appStartMeasurementRead;

+ (void)initialize
{
    if (self == [SentryTracer class]) {
        appStartMeasurementLock = [[NSObject alloc] init];
        appStartMeasurementRead = NO;
    }
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
{
    return [self initWithTransactionContext:transactionContext
                                        hub:hub
                    profilesSamplerDecision:nil
                            waitForChildren:NO
                               timerWrapper:nil];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                           waitForChildren:(BOOL)waitForChildren
{
    return [self initWithTransactionContext:transactionContext
                                        hub:hub
                    profilesSamplerDecision:nil
                            waitForChildren:waitForChildren
                                idleTimeout:0.0
                       dispatchQueueWrapper:nil
                               timerWrapper:nil];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                   profilesSamplerDecision:
                       (nullable SentryProfilesSamplerDecision *)profilesSamplerDecision
                           waitForChildren:(BOOL)waitForChildren
                              timerWrapper:(nullable SentryNSTimerWrapper *)timerWrapper
{
    return [self initWithTransactionContext:transactionContext
                                        hub:hub
                    profilesSamplerDecision:profilesSamplerDecision
                            waitForChildren:waitForChildren
                                idleTimeout:0.0
                       dispatchQueueWrapper:nil
                               timerWrapper:timerWrapper];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                   profilesSamplerDecision:
                       (nullable SentryProfilesSamplerDecision *)profilesSamplerDecision
                               idleTimeout:(NSTimeInterval)idleTimeout
                      dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    return [self initWithTransactionContext:transactionContext
                                        hub:hub
                    profilesSamplerDecision:profilesSamplerDecision
                            waitForChildren:YES
                                idleTimeout:idleTimeout
                       dispatchQueueWrapper:dispatchQueueWrapper
                               timerWrapper:nil];
}

- (instancetype)
    initWithTransactionContext:(SentryTransactionContext *)transactionContext
                           hub:(nullable SentryHub *)hub
       profilesSamplerDecision:(nullable SentryProfilesSamplerDecision *)profilesSamplerDecision
               waitForChildren:(BOOL)waitForChildren
                   idleTimeout:(NSTimeInterval)idleTimeout
          dispatchQueueWrapper:(nullable SentryDispatchQueueWrapper *)dispatchQueueWrapper
                  timerWrapper:(nullable SentryNSTimerWrapper *)timerWrapper
{
    if (self = [super initWithContext:transactionContext]) {
        SENTRY_LOG_DEBUG(
            @"Starting transaction ID %@ and name %@ for span ID %@ at system time %llu",
            transactionContext.traceId.sentryIdString, transactionContext.name,
            transactionContext.spanId.sentrySpanIdString, (unsigned long long)getAbsoluteTime());
        self.transactionContext = transactionContext;
        _children = [[NSMutableArray alloc] init];
        self.hub = hub;
        self.wasFinishCalled = NO;
        _waitForChildren = waitForChildren;
        _measurements = [[NSMutableDictionary alloc] init];
        self.finishStatus = kSentrySpanStatusUndefined;
        self.idleTimeout = idleTimeout;
        self.dispatchQueueWrapper = dispatchQueueWrapper;

        if (timerWrapper == nil) {
            self.timerWrapper = [[SentryNSTimerWrapper alloc] init];
        } else {
            self.timerWrapper = timerWrapper;
        }

        appStartMeasurement = [self getAppStartMeasurement];

        if ([self hasIdleTimeout]) {
            [self dispatchIdleTimeout];
        }

        if ([self isAutoGeneratedTransaction]) {
            [self startDeadlineTimer];
        }

#if SENTRY_HAS_UIKIT
        _startTimeChanged = NO;

        // Store current amount of frames at the beginning to be able to calculate the amount of
        // frames at the end of the transaction.
        SentryFramesTracker *framesTracker = [SentryFramesTracker sharedInstance];
        if (framesTracker.isRunning) {
            SentryScreenFrames *currentFrames = framesTracker.currentFrames;
            initTotalFrames = currentFrames.total;
            initSlowFrames = currentFrames.slow;
            initFrozenFrames = currentFrames.frozen;
        }
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_PROFILING_SUPPORTED
        if (profilesSamplerDecision.decision == kSentrySampleDecisionYes) {
            [SentryProfiler startForSpanID:transactionContext.spanId hub:hub];
        }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }

    return self;
}

- (void)dispatchIdleTimeout
{
    if (_idleTimeoutBlock != nil) {
        [self.dispatchQueueWrapper dispatchCancel:_idleTimeoutBlock];
    }
    __weak SentryTracer *weakSelf = self;
    _idleTimeoutBlock = dispatch_block_create(0, ^{
        if (weakSelf == nil) {
            SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not doing anything.");
            return;
        }
        [weakSelf finishInternal];
    });
    [self.dispatchQueueWrapper dispatchAfter:self.idleTimeout block:_idleTimeoutBlock];
}

- (BOOL)hasIdleTimeout
{
    return self.idleTimeout > 0 && self.dispatchQueueWrapper != nil;
}

- (BOOL)isAutoGeneratedTransaction
{
    return self.waitForChildren || [self hasIdleTimeout];
}

- (void)cancelIdleTimeout
{
    if ([self hasIdleTimeout]) {
        [self.dispatchQueueWrapper dispatchCancel:_idleTimeoutBlock];
    }
}

- (void)startDeadlineTimer
{
    __weak SentryTracer *weakSelf = self;
    self.deadlineTimer =
        [self.timerWrapper scheduledTimerWithTimeInterval:SENTRY_AUTO_TRANSACTION_DEADLINE
                                                  repeats:NO
                                                    block:^(NSTimer *_Nonnull timer) {
                                                        if (weakSelf == nil) {
                                                            return;
                                                        }
                                                        [weakSelf deadlineTimerFired];
                                                    }];
}

- (void)deadlineTimerFired
{
    @synchronized(_children) {
        for (id<SentrySpan> span in _children) {
            if (![span isFinished])
                [span finishWithStatus:kSentrySpanStatusDeadlineExceeded];
        }
    }

    [self finishWithStatus:kSentrySpanStatusDeadlineExceeded];
}

- (void)cancelDeadlineTimer
{
    [self.deadlineTimer invalidate];
    self.deadlineTimer = nil;
}

- (id<SentrySpan>)getActiveSpan
{
    id<SentrySpan> span;

    if (self.delegate) {
        @synchronized(_children) {
            span = [self.delegate activeSpanForTracer:self];
            if (span == nil || ![_children containsObject:span]) {
                span = self;
            }
        }
    } else {
        span = self;
    }

    return span;
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
{
    id<SentrySpan> activeSpan = [self getActiveSpan];
    if (activeSpan == self) {
        return [self startChildWithParentId:self.spanId operation:operation description:nil];
    }
    return [activeSpan startChildWithOperation:operation];
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
{
    id<SentrySpan> activeSpan = [self getActiveSpan];
    if (activeSpan == self) {
        return [self startChildWithParentId:self.spanId
                                  operation:operation
                                description:description];
    }
    return [activeSpan startChildWithOperation:operation description:description];
}

- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
                               operation:(NSString *)operation
                             description:(nullable NSString *)description
{
    [self cancelIdleTimeout];

    if (self.isFinished) {
        SENTRY_LOG_WARN(
            @"Starting a child on a finished span is not supported; it won't be sent to Sentry.");
        return [SentryNoOpSpan shared];
    }

    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:self.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                   spanDescription:description
                                           sampled:self.sampled];

    SentrySpan *child = [[SentrySpan alloc] initWithTracer:self context:context];
    SENTRY_LOG_DEBUG(@"Started child span %@ under %@", child.spanId.sentrySpanIdString,
        parentId.sentrySpanIdString);
    @synchronized(_children) {
        [_children addObject:child];
    }

    return child;
}

- (void)spanFinished:(id<SentrySpan>)finishedSpan
{
    SENTRY_LOG_DEBUG(@"Finished span %@", finishedSpan.spanId.sentrySpanIdString);
    // Calling canBeFinished on self would end up in an endless loop because canBeFinished
    // calls finish again.
    if (finishedSpan == self) {
        SENTRY_LOG_DEBUG(
            @"Cannot call finish on span with id %@", finishedSpan.spanId.sentrySpanIdString);
        return;
    }
    [self canBeFinished];
}

- (SentryTraceContext *)traceContext
{
    if (_traceContext == nil) {
        @synchronized(self) {
            if (_traceContext == nil) {
                _traceContext = [[SentryTraceContext alloc] initWithTracer:self
                                                                     scope:_hub.scope
                                                                   options:SentrySDK.options];
            }
        }
    }
    return _traceContext;
}

- (void)setStartTimestamp:(nullable NSDate *)startTimestamp
{
    super.startTimestamp = startTimestamp;

#if SENTRY_HAS_UIKIT
    _startTimeChanged = YES;
#endif
}

- (NSArray<id<SentrySpan>> *)children
{
    return [_children copy];
}

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value
{
    SentryMeasurementValue *measurement = [[SentryMeasurementValue alloc] initWithValue:value];
    _measurements[name] = measurement;
}

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value unit:(SentryMeasurementUnit *)unit
{
    SentryMeasurementValue *measurement = [[SentryMeasurementValue alloc] initWithValue:value
                                                                                   unit:unit];
    _measurements[name] = measurement;
}

- (void)finish
{
    SENTRY_LOG_DEBUG(
        @"-[SentryTracer finish] for trace ID %@", _traceContext.traceId.sentryIdString);
    [self finishWithStatus:kSentrySpanStatusOk];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    SENTRY_LOG_DEBUG(@"Finished trace %@", self.traceContext.traceId.sentryIdString);
    self.wasFinishCalled = YES;
    _finishStatus = status;
    [self cancelIdleTimeout];
    [self cancelDeadlineTimer];
    [self canBeFinished];
}

- (void)canBeFinished
{
    // Transaction already finished and captured.
    // Sending another transaction and spans with
    // the same SentryId would be an error.
    if (self.isFinished) {
        SENTRY_LOG_DEBUG(@"Span with id %@ is already finished", self.spanId.sentrySpanIdString);
        return;
    }

    BOOL hasUnfinishedChildSpansToWaitFor = [self hasUnfinishedChildSpansToWaitFor];
    if (!self.wasFinishCalled && !hasUnfinishedChildSpansToWaitFor && [self hasIdleTimeout]) {
        SENTRY_LOG_DEBUG(
            @"Span with id %@ isn't waiting on children and needs idle timeout dispatched.",
            self.spanId.sentrySpanIdString);
        [self dispatchIdleTimeout];
        return;
    }

    if (!self.wasFinishCalled || hasUnfinishedChildSpansToWaitFor) {
        SENTRY_LOG_DEBUG(@"Span with id %@ has children but isn't waiting for them right now.",
            self.spanId.sentrySpanIdString);
        return;
    }

    [self finishInternal];
}

- (BOOL)hasUnfinishedChildSpansToWaitFor
{
    if (!_waitForChildren) {
        return NO;
    }

    @synchronized(_children) {
        for (id<SentrySpan> span in _children) {
            if (![span isFinished])
                return YES;
        }
        return NO;
    }
}

- (void)finishInternal
{
    // Keep existing status of auto generated transactions if set by the user.
    if ([self isAutoGeneratedTransaction] && !self.wasFinishCalled
        && self.status != kSentrySpanStatusUndefined) {
        _finishStatus = self.status;
    }
    [super finishWithStatus:_finishStatus];

    if (self.finishCallback) {
        self.finishCallback(self);

        // The callback will only be executed once. No need to keep the reference and we avoid
        // potential retain cycles.
        self.finishCallback = nil;
    }

    if (_hub == nil) {
        return;
    }

    [_hub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        if (span == self) {
            [self->_hub.scope setSpan:nil];
        }
    }];

    @synchronized(_children) {
        if (self.idleTimeout > 0.0 && _children.count == 0) {
            SENTRY_LOG_DEBUG(@"Was waiting for timeout for UI event trace but it had no children, "
                             @"will not keep transaction.");
            return;
        }

        for (id<SentrySpan> span in _children) {
            if (!span.isFinished) {
                [span finishWithStatus:kSentrySpanStatusDeadlineExceeded];

                // Unfinished children should have the same
                // end timestamp as their parent transaction
                span.timestamp = self.timestamp;
            }
        }

        if ([self hasIdleTimeout]) {
            [self trimEndTimestamp];
        }
    }

#if SENTRY_TARGET_PROFILING_SUPPORTED
    [SentryProfiler stopProfilingSpan:self];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    SentryTransaction *transaction = [self toTransaction];

    // Prewarming can execute code up to viewDidLoad of a UIViewController, and keep the app in the
    // background. This can lead to auto-generated transactions lasting for minutes or event hours.
    // Therefore, we drop transactions lasting longer than SENTRY_AUTO_TRANSACTION_MAX_DURATION.
    NSTimeInterval transactionDuration = [self.timestamp timeIntervalSinceDate:self.startTimestamp];
    if ([self isAutoGeneratedTransaction]
        && transactionDuration >= SENTRY_AUTO_TRANSACTION_MAX_DURATION) {
        SENTRY_LOG_INFO(@"Auto generated transaction exceeded the max duration of %f seconds. Not "
                        @"capturing transaction.",
            SENTRY_AUTO_TRANSACTION_MAX_DURATION);
#if SENTRY_TARGET_PROFILING_SUPPORTED
        [SentryProfiler dropTransaction:transaction];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
        return;
    }

    [_hub captureTransaction:transaction withScope:_hub.scope];

#if SENTRY_TARGET_PROFILING_SUPPORTED
    [SentryProfiler linkTransaction:transaction];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (void)trimEndTimestamp
{
    NSDate *oldest = self.startTimestamp;

    for (id<SentrySpan> childSpan in _children) {
        if ([oldest compare:childSpan.timestamp] == NSOrderedAscending) {
            oldest = childSpan.timestamp;
        }
    }

    if (oldest) {
        self.timestamp = oldest;
    }
}

- (SentryTransaction *)toTransaction
{
    NSArray<id<SentrySpan>> *appStartSpans = [self buildAppStartSpans];

    NSArray<id<SentrySpan>> *spans;
    @synchronized(_children) {
        [_children addObjectsFromArray:appStartSpans];
        spans = [_children copy];
    }

    if (appStartMeasurement != nil) {
        [self setStartTimestamp:appStartMeasurement.appStartTimestamp];
    }

    SentryTransaction *transaction = [[SentryTransaction alloc] initWithTrace:self children:spans];
    transaction.transaction = self.transactionContext.name;

    NSMutableArray *framesOfAllSpans = [NSMutableArray array];
    if ([(SentrySpan *)self frames]) {
        [framesOfAllSpans addObjectsFromArray:[(SentrySpan *)self frames]];
    }

    for (SentrySpan *span in _children) {
        if (span.frames) {
            [framesOfAllSpans addObjectsFromArray:span.frames];
        }
    }

    if (framesOfAllSpans.count > 0) {
        SentryDebugImageProvider *debugImageProvider
            = SentryDependencyContainer.sharedInstance.debugImageProvider;
        transaction.debugMeta = [debugImageProvider getDebugImagesForFrames:framesOfAllSpans];
    }

    [self addMeasurements:transaction];
    return transaction;
}

- (nullable SentryAppStartMeasurement *)getAppStartMeasurement
{
    // Only send app start measurement for transactions generated by auto performance
    // instrumentation.
    if (![self.operation isEqualToString:SentrySpanOperationUILoad]) {
        return nil;
    }

    // Hybrid SDKs send the app start measurement themselves.
    if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
        return nil;
    }

    // Double-Checked Locking to avoid acquiring unnecessary locks.
    if (appStartMeasurementRead == YES) {
        return nil;
    }

    SentryAppStartMeasurement *measurement = nil;
    @synchronized(appStartMeasurementLock) {
        if (appStartMeasurementRead == YES) {
            return nil;
        }

        measurement = [SentrySDK getAppStartMeasurement];
        if (measurement == nil) {
            return nil;
        }

        appStartMeasurementRead = YES;
    }

    NSDate *appStartTimestamp = measurement.appStartTimestamp;
    NSDate *appStartEndTimestamp =
        [appStartTimestamp dateByAddingTimeInterval:measurement.duration];

    NSTimeInterval difference = [appStartEndTimestamp timeIntervalSinceDate:self.startTimestamp];

    // If the difference between the end of the app start and the beginning of the current
    // transaction is smaller than SENTRY_APP_START_MEASUREMENT_DIFFERENCE. With this we
    // avoid messing up transactions too much.
    if (difference > SENTRY_APP_START_MEASUREMENT_DIFFERENCE
        || difference < -SENTRY_APP_START_MEASUREMENT_DIFFERENCE) {
        return nil;
    }

    return measurement;
}

- (NSArray<SentrySpan *> *)buildAppStartSpans
{
    if (appStartMeasurement == nil) {
        return @[];
    }

    NSString *operation;
    NSString *type;

    switch (appStartMeasurement.type) {
    case SentryAppStartTypeCold:
        operation = @"app.start.cold";
        type = @"Cold Start";
        break;
    case SentryAppStartTypeWarm:
        operation = @"app.start.warm";
        type = @"Warm Start";
        break;
    default:
        return @[];
    }

    NSMutableArray<SentrySpan *> *appStartSpans = [NSMutableArray array];

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

    SentrySpan *appStartSpan = [self buildSpan:self.spanId operation:operation description:type];
    [appStartSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
    [appStartSpan setTimestamp:appStartEndTimestamp];

    [appStartSpans addObject:appStartSpan];

    if (!appStartMeasurement.isPreWarmed) {
        SentrySpan *premainSpan = [self buildSpan:appStartSpan.spanId
                                        operation:operation
                                      description:@"Pre Runtime Init"];
        [premainSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [premainSpan setTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [appStartSpans addObject:premainSpan];

        SentrySpan *runtimeInitSpan = [self buildSpan:appStartSpan.spanId
                                            operation:operation
                                          description:@"Runtime Init to Pre Main Initializers"];
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.moduleInitializationTimestamp];
        [appStartSpans addObject:runtimeInitSpan];
    }

    SentrySpan *appInitSpan = [self buildSpan:appStartSpan.spanId
                                    operation:operation
                                  description:@"UIKit and Application Init"];
    [appInitSpan setStartTimestamp:appStartMeasurement.moduleInitializationTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [appStartSpans addObject:appInitSpan];

    SentrySpan *frameRenderSpan = [self buildSpan:appStartSpan.spanId
                                        operation:operation
                                      description:@"Initial Frame Render"];
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];
    [appStartSpans addObject:frameRenderSpan];

    return appStartSpans;
}

- (void)addMeasurements:(SentryTransaction *)transaction
{
    if (appStartMeasurement != nil && appStartMeasurement.type != SentryAppStartTypeUnknown) {
        NSString *type = nil;
        NSString *appContextType = nil;
        if (appStartMeasurement.type == SentryAppStartTypeCold) {
            type = @"app_start_cold";
            appContextType = @"cold";
        } else if (appStartMeasurement.type == SentryAppStartTypeWarm) {
            type = @"app_start_warm";
            appContextType = @"warm";
        }

        if (type != nil && appContextType != nil) {
            [self setMeasurement:type value:@(appStartMeasurement.duration * 1000)];

            NSString *appStartType = appStartMeasurement.isPreWarmed
                ? [NSString stringWithFormat:@"%@.prewarmed", appContextType]
                : appContextType;
            NSMutableDictionary *context =
                [[NSMutableDictionary alloc] initWithDictionary:[transaction context]];
            NSDictionary *appContext = @{ @"app" : @ { @"start_type" : appStartType } };
            [context mergeEntriesFromDictionary:appContext];
            [transaction setContext:context];
        }
    }

#if SENTRY_HAS_UIKIT
    // Frames
    SentryFramesTracker *framesTracker = [SentryFramesTracker sharedInstance];
    if (framesTracker.isRunning && !_startTimeChanged) {

        SentryScreenFrames *currentFrames = framesTracker.currentFrames;
        NSInteger totalFrames = currentFrames.total - initTotalFrames;
        NSInteger slowFrames = currentFrames.slow - initSlowFrames;
        NSInteger frozenFrames = currentFrames.frozen - initFrozenFrames;

        BOOL allBiggerThanZero = totalFrames >= 0 && slowFrames >= 0 && frozenFrames >= 0;
        BOOL oneBiggerThanZero = totalFrames > 0 || slowFrames > 0 || frozenFrames > 0;

        if (allBiggerThanZero && oneBiggerThanZero) {
            [self setMeasurement:@"frames_total" value:@(totalFrames)];
            [self setMeasurement:@"frames_slow" value:@(slowFrames)];
            [self setMeasurement:@"frames_frozen" value:@(frozenFrames)];

            SENTRY_LOG_DEBUG(@"Frames for transaction \"%@\" Total:%ld Slow:%ld Frozen:%ld",
                self.operation, (long)totalFrames, (long)slowFrames, (long)frozenFrames);
        }
    }
#endif
}

- (id<SentrySpan>)buildSpan:(SentrySpanId *)parentId
                  operation:(NSString *)operation
                description:(NSString *)description
{
    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:self.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                   spanDescription:description
                                           sampled:self.sampled];

    return [[SentrySpan alloc] initWithTracer:self context:context];
}

/**
 * Internal. Only needed for testing.
 */
+ (void)resetAppStartMeasurementRead
{
    @synchronized(appStartMeasurementLock) {
        appStartMeasurementRead = NO;
    }
}

+ (nullable SentryTracer *)getTracer:(id<SentrySpan>)span
{
    if (span == nil) {
        return nil;
    }

    if ([span isKindOfClass:[SentryTracer class]]) {
        return span;
    } else if ([span isKindOfClass:[SentrySpan class]]) {
        return [(SentrySpan *)span tracer];
    }
    return nil;
}

@end

NS_ASSUME_NONNULL_END
