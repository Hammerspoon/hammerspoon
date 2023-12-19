#import "NSDictionary+SentrySanitize.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryClient.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDebugImageProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryNSTimerFactory.h"
#import "SentryNoOpSpan.h"
#import "SentryProfilingConditionals.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryThreadWrapper.h"
#import "SentryTime.h"
#import "SentryTraceContext.h"
#import "SentryTraceOrigins.h"
#import "SentryTracer+Private.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"
#import "SentryUIApplication.h"
#import <NSMutableDictionary+Sentry.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryMeasurementValue.h>
#import <SentrySpanOperations.h>
@import SentryPrivate;

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfiler.h"
#    import "SentryProfilesSampler.h"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#if SENTRY_HAS_UIKIT
#    import "SentryAppStartMeasurement.h"
#    import "SentryBuildAppStartSpans.h"
#    import "SentryFramesTracker.h"
#    import "SentryUIViewControllerPerformanceTracker.h"
#    import <SentryScreenFrames.h>
#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

static const void *spanTimestampObserver = &spanTimestampObserver;

#if SENTRY_HAS_UIKIT
/**
 * The maximum amount of seconds the app start measurement end time and the start time of the
 * transaction are allowed to be apart.
 */
static const NSTimeInterval SENTRY_APP_START_MEASUREMENT_DIFFERENCE = 5.0;
#endif // SENTRY_HAS_UIKIT

static const NSTimeInterval SENTRY_AUTO_TRANSACTION_MAX_DURATION = 500.0;
static const NSTimeInterval SENTRY_AUTO_TRANSACTION_DEADLINE = 30.0;

@interface
SentryTracer ()

@property (nonatomic) SentrySpanStatus finishStatus;
/** This property is different from @c isFinished. While @c isFinished states if the tracer is
 * actually finished, this property tells you if finish was called on the tracer. Calling
 * @c -[finish] doesn't necessarily lead to finishing the tracer, because it could still wait for
 * child spans to finish if @c waitForChildren is @c YES . */
@property (nonatomic) BOOL wasFinishCalled;
@property (nonatomic, nullable, strong) NSTimer *deadlineTimer;
@property (nonnull, strong) SentryTracerConfiguration *configuration;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic) BOOL isProfiling;
@property (nonatomic) uint64_t startSystemTime;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

@implementation SentryTracer {
    /** Wether the tracer should wait for child spans to finish before finishing itself. */
    SentryTraceContext *_traceContext;

#if SENTRY_HAS_UIKIT
    SentryAppStartMeasurement *appStartMeasurement;
#endif // SENTRY_HAS_UIKIT
    NSMutableDictionary<NSString *, SentryMeasurementValue *> *_measurements;
    dispatch_block_t _idleTimeoutBlock;
    NSMutableArray<id<SentrySpan>> *_children;
    BOOL _startTimeChanged;
    NSDate *_originalStartTimestamp;
    NSObject *_idleTimeoutLock;

#if SENTRY_HAS_UIKIT
    NSUInteger initTotalFrames;
    NSUInteger initSlowFrames;
    NSUInteger initFrozenFrames;
    NSArray<NSString *> *viewNames;
#endif // SENTRY_HAS_UIKIT
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
                              configuration:SentryTracerConfiguration.defaultConfiguration];
}

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                             configuration:(SentryTracerConfiguration *)configuration;
{
    if (!(self = [super initWithContext:transactionContext])) {
        return nil;
    }

    _configuration = configuration;

    self.transactionContext = transactionContext;
    _children = [[NSMutableArray alloc] init];
    self.hub = hub;
    self.wasFinishCalled = NO;
    _measurements = [[NSMutableDictionary alloc] init];
    self.finishStatus = kSentrySpanStatusUndefined;

    if (_configuration.timerFactory == nil) {
        _configuration.timerFactory = [[SentryNSTimerFactory alloc] init];
    }

#if SENTRY_HAS_UIKIT
    appStartMeasurement = [self getAppStartMeasurement];
    viewNames = [SentryDependencyContainer.sharedInstance.application relevantViewControllersNames];
#endif // SENTRY_HAS_UIKIT

    _idleTimeoutLock = [[NSObject alloc] init];
    if ([self hasIdleTimeout]) {
        [self dispatchIdleTimeout];
    }

    if ([self isAutoGeneratedTransaction]) {
        [self startDeadlineTimer];
    }

#if SENTRY_HAS_UIKIT
    // Store current amount of frames at the beginning to be able to calculate the amount of
    // frames at the end of the transaction.
    SentryFramesTracker *framesTracker = SentryDependencyContainer.sharedInstance.framesTracker;
    if (framesTracker.isRunning) {
        SentryScreenFrames *currentFrames = framesTracker.currentFrames;
        initTotalFrames = currentFrames.total;
        initSlowFrames = currentFrames.slow;
        initFrozenFrames = currentFrames.frozen;
    }
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_PROFILING_SUPPORTED
    if (_configuration.profilesSamplerDecision.decision == kSentrySampleDecisionYes) {
        _startSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
        _internalID = [[SentryId alloc] init];
        _isProfiling = [SentryProfiler startWithTracer:_internalID];
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    return self;
}

- (void)dealloc
{
#if SENTRY_TARGET_PROFILING_SUPPORTED
    if (self.isProfiling) {
        discardProfilerForTracer(self.internalID);
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (nullable SentryTracer *)tracer
{
    return self;
}

- (void)dispatchIdleTimeout
{
    @synchronized(_idleTimeoutLock) {
        if (_idleTimeoutBlock != NULL) {
            [_configuration.dispatchQueueWrapper dispatchCancel:_idleTimeoutBlock];
        }
        __weak SentryTracer *weakSelf = self;
        _idleTimeoutBlock = [_configuration.dispatchQueueWrapper createDispatchBlock:^{
            if (weakSelf == nil) {
                SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not doing anything.");
                return;
            }
            [weakSelf finishInternal];
        }];

        if (_idleTimeoutBlock == NULL) {
            SENTRY_LOG_WARN(@"Couldn't create idle time out block. Can't schedule idle timeout. "
                            @"Finishing transaction");
            // If the transaction has no children, the SDK will discard it.
            [self finishInternal];
        } else {
            [_configuration.dispatchQueueWrapper dispatchAfter:_configuration.idleTimeout
                                                         block:_idleTimeoutBlock];
        }
    }
}

- (BOOL)hasIdleTimeout
{
    return _configuration.idleTimeout > 0 && _configuration.dispatchQueueWrapper != nil;
}

- (BOOL)isAutoGeneratedTransaction
{
    return _configuration.waitForChildren || [self hasIdleTimeout];
}

- (void)cancelIdleTimeout
{
    @synchronized(_idleTimeoutLock) {
        if ([self hasIdleTimeout]) {
            [_configuration.dispatchQueueWrapper dispatchCancel:_idleTimeoutBlock];
        }
    }
}

- (void)startDeadlineTimer
{
    __weak SentryTracer *weakSelf = self;
    [_configuration.dispatchQueueWrapper dispatchOnMainQueue:^{
        weakSelf.deadlineTimer = [weakSelf.configuration.timerFactory
            scheduledTimerWithTimeInterval:SENTRY_AUTO_TRANSACTION_DEADLINE
                                   repeats:NO
                                     block:^(NSTimer *_Nonnull timer) {
                                         if (weakSelf == nil) {
                                             SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not calling "
                                                              @"deadlineTimerFired.");
                                             return;
                                         }
                                         [weakSelf deadlineTimerFired];
                                     }];
    }];
}

- (void)deadlineTimerFired
{
    SENTRY_LOG_DEBUG(@"Sentry tracer deadline fired");
    @synchronized(self) {
        // This try to minimize a race condition with a proper call to `finishInternal`.
        if (self.isFinished) {
            return;
        }
    }

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
    // If the main thread is busy the tracer could be deallocated in between.
    __weak SentryTracer *weakSelf = self;

    // The timer must be invalidated from the thread on which the timer was installed, see
    // https://developer.apple.com/documentation/foundation/nstimer/1415405-invalidate#1770468
    [_configuration.dispatchQueueWrapper dispatchOnMainQueue:^{
        if (weakSelf == nil) {
            SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not invalidating deadlineTimer.");
            return;
        }
        [weakSelf.deadlineTimer invalidate];
        weakSelf.deadlineTimer = nil;
    }];
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
    child.startTimestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
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
    [self finishWithStatus:kSentrySpanStatusOk];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    SENTRY_LOG_DEBUG(@"Finished trace with traceID: %@ and status: %@", self.traceId.sentryIdString,
        nameForSentrySpanStatus(status));
    self.wasFinishCalled = YES;
    _finishStatus = status;
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
    if (!self.configuration.waitForChildren) {
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
    [self cancelDeadlineTimer];
    if (self.isFinished) {
        return;
    }
    @synchronized(self) {
        if (self.isFinished) {
            return;
        }
        // Keep existing status of auto generated transactions if set by the user.

        if ([self isAutoGeneratedTransaction] && !self.wasFinishCalled
            && self.status != kSentrySpanStatusUndefined) {
            _finishStatus = self.status;
        }
        [super finishWithStatus:_finishStatus];
    }
    [self.delegate tracerDidFinish:self];

    if (self.finishCallback) {
        self.finishCallback(self);

        // The callback will only be executed once. No need to keep the reference and we avoid
        // potential retain cycles.
        self.finishCallback = nil;
    }

#if SENTRY_HAS_UIKIT
    if (appStartMeasurement != nil) {
        [self updateStartTime:appStartMeasurement.appStartTimestamp];
    }
#endif // SENTRY_HAS_UIKIT

    // Prewarming can execute code up to viewDidLoad of a UIViewController, and keep the app in the
    // background. This can lead to auto-generated transactions lasting for minutes or even hours.
    // Therefore, we drop transactions lasting longer than SENTRY_AUTO_TRANSACTION_MAX_DURATION.
    NSTimeInterval transactionDuration = [self.timestamp timeIntervalSinceDate:self.startTimestamp];
    if ([self isAutoGeneratedTransaction]
        && transactionDuration >= SENTRY_AUTO_TRANSACTION_MAX_DURATION) {
        SENTRY_LOG_INFO(@"Auto generated transaction exceeded the max duration of %f seconds. Not "
                        @"capturing transaction.",
            SENTRY_AUTO_TRANSACTION_MAX_DURATION);
        return;
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
        if (_configuration.idleTimeout > 0.0 && _children.count == 0) {
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

        if ([self isAutoGeneratedTransaction]) {
            [self trimEndTimestamp];
        }
    }

    SentryTransaction *transaction = [self toTransaction];

#if SENTRY_TARGET_PROFILING_SUPPORTED
    if (self.isProfiling) {
        [self captureTransactionWithProfile:transaction];
        return;
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    [_hub captureTransaction:transaction withScope:_hub.scope];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)captureTransactionWithProfile:(SentryTransaction *)transaction
{
    SentryEnvelopeItem *profileEnvelopeItem =
        [SentryProfiler createProfilingEnvelopeItemForTransaction:transaction];

    if (!profileEnvelopeItem) {
        [_hub captureTransaction:transaction withScope:_hub.scope];
        return;
    }

    SENTRY_LOG_DEBUG(@"Capturing transaction with profiling data attached.");
    [_hub captureTransaction:transaction
                      withScope:_hub.scope
        additionalEnvelopeItems:@[ profileEnvelopeItem ]];
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)trimEndTimestamp
{
    NSDate *oldest = self.startTimestamp;

    @synchronized(_children) {
        for (id<SentrySpan> childSpan in _children) {
            if ([oldest compare:childSpan.timestamp] == NSOrderedAscending) {
                oldest = childSpan.timestamp;
            }
        }
    }

    if (oldest) {
        self.timestamp = oldest;
    }
}

- (void)updateStartTime:(NSDate *)startTime
{
    _originalStartTimestamp = self.startTimestamp;
    super.startTimestamp = startTime;
    _startTimeChanged = YES;
}

- (SentryTransaction *)toTransaction
{
    NSUInteger capacity;
#if SENTRY_HAS_UIKIT
    NSArray<id<SentrySpan>> *appStartSpans = sentryBuildAppStartSpans(self, appStartMeasurement);
    capacity = _children.count + appStartSpans.count;
#else
    capacity = _children.count;
#endif // SENTRY_HAS_UIKIT

    NSMutableArray<id<SentrySpan>> *spans = [[NSMutableArray alloc] initWithCapacity:capacity];

    @synchronized(_children) {
        [spans addObjectsFromArray:_children];
    }

#if SENTRY_HAS_UIKIT
    [spans addObjectsFromArray:appStartSpans];
#endif // SENTRY_HAS_UIKIT

    SentryTransaction *transaction = [[SentryTransaction alloc] initWithTrace:self children:spans];
    transaction.transaction = self.transactionContext.name;
#if SENTRY_TARGET_PROFILING_SUPPORTED
    transaction.startSystemTime = self.startSystemTime;
    if (self.isProfiling) {
        [SentryProfiler recordMetrics];
    }
    transaction.endSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    NSMutableArray *framesOfAllSpans = [NSMutableArray array];
    if ([(SentrySpan *)self frames]) {
        [framesOfAllSpans addObjectsFromArray:[(SentrySpan *)self frames]];
    }

    for (SentrySpan *span in spans) {
        if (span.frames) {
            [framesOfAllSpans addObjectsFromArray:span.frames];
        }
    }

    if (framesOfAllSpans.count > 0) {
        SentryDebugImageProvider *debugImageProvider
            = SentryDependencyContainer.sharedInstance.debugImageProvider;
        transaction.debugMeta = [debugImageProvider getDebugImagesForFrames:framesOfAllSpans
                                                                    isCrash:NO];
    }

#if SENTRY_HAS_UIKIT
    [self addMeasurements:transaction];

    if ([viewNames count] > 0) {
        transaction.viewNames = viewNames;
    }
#endif // SENTRY_HAS_UIKIT

    return transaction;
}

#if SENTRY_HAS_UIKIT

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

    // Don't attach app start measurements if too much time elapsed between the end of the app start
    // sequence and the start of the transaction. This makes transactions too long.
    if (difference > SENTRY_APP_START_MEASUREMENT_DIFFERENCE
        || difference < -SENTRY_APP_START_MEASUREMENT_DIFFERENCE) {
        return nil;
    }

    return measurement;
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

    // Frames
    SentryFramesTracker *framesTracker = SentryDependencyContainer.sharedInstance.framesTracker;
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
}

#endif // SENTRY_HAS_UIKIT

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

- (NSDate *)originalStartTimestamp
{
    return _startTimeChanged ? _originalStartTimestamp : self.startTimestamp;
}

@end

NS_ASSUME_NONNULL_END
