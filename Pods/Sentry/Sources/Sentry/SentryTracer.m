#import "PrivateSentrySDKOnly.h"
#import "SentryClient.h"
#import "SentryDebugImageProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryInternalCDefines.h"
#import "SentryInternalDefines.h"
#import "SentryLog.h"
#import "SentryNSDictionarySanitize.h"
#import "SentryNSTimerFactory.h"
#import "SentryNoOpSpan.h"
#import "SentryOptions+Private.h"
#import "SentryProfilingConditionals.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentrySamplerDecision.h"
#import "SentryScope+Private.h"
#import "SentrySpan.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentrySwift.h"
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

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryLaunchProfiling.h"
#    import "SentryProfiledTracerConcurrency.h"
#    import "SentryProfilerSerialization.h"
#    import "SentryTraceProfiler.h"
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

static const NSTimeInterval SENTRY_AUTO_TRANSACTION_DEADLINE = 30.0;

@interface
SentryTracer ()

@property (nonatomic) uint64_t startSystemTime;
@property (nonatomic) SentrySpanStatus finishStatus;
/** This property is different from @c isFinished. While @c isFinished states if the tracer is
 * actually finished, this property tells you if finish was called on the tracer. Calling
 * @c -[finish] doesn't necessarily lead to finishing the tracer, because it could still wait for
 * child spans to finish if @c waitForChildren is @c YES . */
@property (nonatomic) BOOL wasFinishCalled;
@property (nonatomic, nullable, strong) NSTimer *deadlineTimer;
@property (nonnull, strong) SentryTracerConfiguration *configuration;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic) BOOL isProfiling;
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
    if (!(self = [super initWithContext:transactionContext
#if SENTRY_HAS_UIKIT
                          framesTracker:SentryDependencyContainer.sharedInstance.framesTracker
#endif // SENTRY_HAS_UIKIT
    ])) {
        return nil;
    }

    _startSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    _configuration = configuration;
    _dispatchQueue = SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
    _debugImageProvider = SentryDependencyContainer.sharedInstance.debugImageProvider;

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
    [hub configureScope:^(SentryScope *scope) {
        if (scope.currentScreen != nil) {
            self->viewNames = @[ scope.currentScreen ];
        }
    }];

    if (viewNames == nil) {
        viewNames =
            [SentryDependencyContainer.sharedInstance.application relevantViewControllersNames];
    }

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
    BOOL profileShouldBeSampled
        = _configuration.profilesSamplerDecision.decision == kSentrySampleDecisionYes;
    BOOL isContinuousProfiling = [hub.client.options isContinuousProfilingEnabled];
    BOOL shouldStartNormalTraceProfile = !isContinuousProfiling && profileShouldBeSampled;
    if (sentry_isTracingAppLaunch || shouldStartNormalTraceProfile) {
        _internalID = [[SentryId alloc] init];
        if ((_isProfiling = [SentryTraceProfiler startWithTracer:_internalID])) {
            SENTRY_LOG_DEBUG(@"Started profiler for trace %@ with internal id %@",
                transactionContext.traceId.sentryIdString, _internalID.sentryIdString);
        }
        _startSystemTime = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    SENTRY_LOG_DEBUG(@"Started tracer with id: %@", transactionContext.traceId.sentryIdString);

    return self;
}

- (void)dealloc
{
#if SENTRY_TARGET_PROFILING_SUPPORTED
    if (self.isProfiling) {
        sentry_discardProfilerForTracer(self.internalID);
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
            [_dispatchQueue dispatchCancel:_idleTimeoutBlock];
        }
        __weak SentryTracer *weakSelf = self;
        _idleTimeoutBlock = [_dispatchQueue createDispatchBlock:^{
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
            [_dispatchQueue dispatchAfter:_configuration.idleTimeout block:_idleTimeoutBlock];
        }
    }
}

- (BOOL)hasIdleTimeout
{
    return _configuration.idleTimeout > 0;
}

- (BOOL)isAutoGeneratedTransaction
{
    return _configuration.waitForChildren || [self hasIdleTimeout];
}

- (void)cancelIdleTimeout
{
    @synchronized(_idleTimeoutLock) {
        if ([self hasIdleTimeout]) {
            [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper
                dispatchCancel:_idleTimeoutBlock];
        }
    }
}

- (void)startDeadlineTimer
{
    __weak SentryTracer *weakSelf = self;
    [_dispatchQueue dispatchAsyncOnMainQueue:^{
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
    [_dispatchQueue dispatchAsyncOnMainQueue:^{
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

    SentrySpan *child =
        [[SentrySpan alloc] initWithTracer:self
                                   context:context
#if SENTRY_HAS_UIKIT
                             framesTracker:SentryDependencyContainer.sharedInstance.framesTracker
#endif // SENTRY_HAS_UIKIT
    ];
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
    SENTRY_LOG_DEBUG(@"Finished trace with traceID: %@ and status: %@",
        self.internalID.sentryIdString, nameForSentrySpanStatus(status));
    @synchronized(self) {
        self.wasFinishCalled = YES;
    }
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

    @synchronized(self) {
        if (!self.wasFinishCalled && !hasUnfinishedChildSpansToWaitFor && [self hasIdleTimeout]) {
            SENTRY_LOG_DEBUG(
                @"Span with id %@ isn't waiting on children and needs idle timeout dispatched.",
                self.spanId.sentrySpanIdString);
            [self dispatchIdleTimeout];
            return;
        }

        if (!self.wasFinishCalled || hasUnfinishedChildSpansToWaitFor) {
            SENTRY_LOG_DEBUG(
                @"Span with id %@ has children but hasn't finished yet so isn't waiting "
                @"for them right now.",
                self.spanId.sentrySpanIdString);
            return;
        }
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
            if (self.shouldIgnoreWaitForChildrenCallback != nil
                && self.shouldIgnoreWaitForChildrenCallback(span)) {
                continue;
            }
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
        SENTRY_LOG_DEBUG(@"Tracer %@ was already finished.", _traceContext.traceId.sentryIdString);
        return;
    }
    @synchronized(self) {
        if (self.isFinished) {
            SENTRY_LOG_DEBUG(@"Tracer %@ was already finished after synchronizing.",
                _traceContext.traceId.sentryIdString);
            return;
        }
        // Keep existing status of auto generated transactions if set by the user.

        if ([self isAutoGeneratedTransaction] && !self.wasFinishCalled
            && self.status != kSentrySpanStatusUndefined) {
            _finishStatus = self.status;
        }
        [super finishWithStatus:_finishStatus];
    }
#if SENTRY_HAS_UIKIT
    appStartMeasurement = [self getAppStartMeasurement];

    if (appStartMeasurement != nil) {
        [self updateStartTime:appStartMeasurement.appStartTimestamp];
    }
#endif // SENTRY_HAS_UIKIT

    [self.delegate tracerDidFinish:self];

    if (self.finishCallback) {
        self.finishCallback(self);

        // The callback will only be executed once. No need to keep the reference and we avoid
        // potential retain cycles.
        self.finishCallback = nil;
    }

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
        SENTRY_LOG_DEBUG(
            @"Hub was nil for tracer %@, nothing to do.", _traceContext.traceId.sentryIdString);
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
        NSDate *startTimestamp;

#    if SENTRY_HAS_UIKIT
        if (appStartMeasurement != nil) {
            startTimestamp = appStartMeasurement.runtimeInitTimestamp;
        }
#    endif // SENTRY_HAS_UIKIT

        if (startTimestamp == nil) {
            startTimestamp = self.startTimestamp;
        }
        if (!SENTRY_ASSERT_RETURN(startTimestamp != nil,
                @"A transaction with a profile should have a start timestamp already. We will "
                @"assign the current time but this will be incorrect.")) {
            startTimestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
        }

        [self captureTransactionWithProfile:transaction startTimestamp:startTimestamp];
        return;
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    [_hub captureTransaction:transaction withScope:_hub.scope];
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)captureTransactionWithProfile:(SentryTransaction *)transaction
                       startTimestamp:(NSDate *)startTimestamp
{
    SentryEnvelopeItem *profileEnvelopeItem
        = sentry_traceProfileEnvelopeItem(transaction, startTimestamp);

    if (!profileEnvelopeItem) {
        [_hub captureTransaction:transaction withScope:_hub.scope];
        return;
    }

    SENTRY_LOG_DEBUG(@"Capturing transaction id %@ with profiling data attached for tracer id %@.",
        transaction.eventId.sentryIdString, self.internalID.sentryIdString);
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
    super.startTimestamp = startTime;
    _startTimeChanged = YES;
}

- (SentryTransaction *)toTransaction
{

    NSUInteger capacity;
#if SENTRY_HAS_UIKIT
    [self addFrameStatistics];

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
    if (self.isProfiling) {
        // if we have an app start span, use its app start timestamp. otherwise use the tracer's
        // start system time as we currently do
        SENTRY_LOG_DEBUG(@"Tracer start time: %llu", self.startSystemTime);

        transaction.startSystemTime = self.startSystemTime;
#    if SENTRY_HAS_UIKIT
        if (appStartMeasurement != nil) {
            SENTRY_LOG_DEBUG(@"Assigning transaction start time as app start system time (%llu)",
                appStartMeasurement.runtimeInitSystemTimestamp);
            transaction.startSystemTime = appStartMeasurement.runtimeInitSystemTimestamp;
        }
#    endif // SENTRY_HAS_UIKIT

        [SentryTraceProfiler recordMetrics];
        transaction.endSystemTime
            = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    }
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
    [self addAppStartMeasurements:transaction];

    if ([viewNames count] > 0) {
        transaction.viewNames = viewNames;
    }
#endif // SENTRY_HAS_UIKIT

    return transaction;
}

#if SENTRY_HAS_UIKIT

- (nullable SentryAppStartMeasurement *)getAppStartMeasurement SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    // Only send app start measurement for transactions generated by auto performance
    // instrumentation.
    if (![self.operation isEqualToString:SentrySpanOperationUILoad]) {
        SENTRY_LOG_DEBUG(
            @"Not returning app start measurements because it's not a ui.load operation.");
        return nil;
    }

    // Hybrid SDKs send the app start measurement themselves.
    if (PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode) {
        SENTRY_LOG_DEBUG(@"Not returning app start measurements because hybrid SDK will do it in "
                         @"its own routine.");
        return nil;
    }

    // Double-Checked Locking to avoid acquiring unnecessary locks.
    if (appStartMeasurementRead == YES) {
        SENTRY_LOG_DEBUG(@"Not returning app start measurements because it was already reported.");
        return nil;
    }

    SentryAppStartMeasurement *measurement = nil;
    @synchronized(appStartMeasurementLock) {
        if (appStartMeasurementRead == YES) {
            SENTRY_LOG_DEBUG(@"Not returning app start measurements because it was already "
                             @"reported concurrently.");
            return nil;
        }

        measurement = [SentrySDK getAppStartMeasurement];
        if (measurement == nil) {
            SENTRY_LOG_DEBUG(@"No app start measurement available.");
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
        SENTRY_LOG_DEBUG(@"Not returning app start measurements because too much time elapsed.");
        return nil;
    }

    SENTRY_LOG_DEBUG(
        @"Returning app start measurements for trace id %@", self.internalID.sentryIdString);
    return measurement;
}

- (void)addAppStartMeasurements:(SentryTransaction *)transaction
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
            [SentryDictionary mergeEntriesFromDictionary:appContext intoDictionary:context];
            [transaction setContext:context];

            // The backend calculates statistics on the number and size of debug images for app
            // start transactions. Therefore, we add all debug images here.
            transaction.debugMeta = [self.debugImageProvider getDebugImagesCrashed:NO];
        }
    }
}

- (void)addFrameStatistics
{
    SentryFramesTracker *framesTracker = SentryDependencyContainer.sharedInstance.framesTracker;
    if (framesTracker.isRunning) {
        CFTimeInterval framesDelay = [framesTracker
                getFramesDelay:self.startSystemTime
            endSystemTimestamp:SentryDependencyContainer.sharedInstance.dateProvider.systemTime];

        if (framesDelay >= 0) {
            [self setDataValue:@(framesDelay) forKey:@"frames.delay"];
            SENTRY_LOG_DEBUG(@"Frames Delay:%f ms", framesDelay * 1000);
        }

        if (!_startTimeChanged) {
            SentryScreenFrames *currentFrames = framesTracker.currentFrames;
            NSInteger totalFrames = currentFrames.total - initTotalFrames;
            NSInteger slowFrames = currentFrames.slow - initSlowFrames;
            NSInteger frozenFrames = currentFrames.frozen - initFrozenFrames;

            if (sentryShouldAddSlowFrozenFramesData(totalFrames, slowFrames, frozenFrames)) {
                [self setMeasurement:@"frames_total" value:@(totalFrames)];
                [self setMeasurement:@"frames_slow" value:@(slowFrames)];
                [self setMeasurement:@"frames_frozen" value:@(frozenFrames)];

                SENTRY_LOG_DEBUG(@"Frames for transaction \"%@\" Total:%ld Slow:%ld "
                                 @"Frozen:%ld",
                    self.operation, (long)totalFrames, (long)slowFrames, (long)frozenFrames);
            }
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

@end

NS_ASSUME_NONNULL_END
