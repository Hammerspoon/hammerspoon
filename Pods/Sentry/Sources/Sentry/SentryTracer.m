#import "PrivateSentrySDKOnly.h"
#import "SentryClient.h"
#import "SentryDebugImageProvider+HybridSDKs.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryInternalCDefines.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryNSDictionarySanitize.h"
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
#import "SentrySpanOperation.h"
#import "SentrySwift.h"
#import "SentryThreadWrapper.h"
#import "SentryTime.h"
#import "SentryTraceContext.h"
#import "SentryTracer+Private.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"
#import "SentryUIApplication.h"
#import <NSMutableDictionary+Sentry.h>
#import <SentryMeasurementValue.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryProfiledTracerConcurrency.h"
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

@interface SentryTracer ()

@property (nonatomic) uint64_t startSystemTime;
@property (nonatomic) SentrySpanStatus finishStatus;
/** This property is different from @c isFinished. While @c isFinished states if the tracer is
 * actually finished, this property tells you if finish was called on the tracer. Calling
 * @c -[finish] doesn't necessarily lead to finishing the tracer, because it could still wait for
 * child spans to finish if @c waitForChildren is @c YES . */
@property (nonatomic) BOOL wasFinishCalled;
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
    NSObject *_dispatchTimeoutLock;
    dispatch_block_t _idleTimeoutBlock;
    dispatch_block_t _deadlineTimeoutBlock;
    NSMutableArray<id<SentrySpan>> *_children;
    BOOL _startTimeChanged;

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

    _dispatchTimeoutLock = [[NSObject alloc] init];
    if ([self hasIdleTimeout]) {
        [self startIdleTimeout];
    }

    if ([self isAutoGeneratedTransaction]) {
        [self startDeadlineTimeout];
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
    _profilerReferenceID = sentry_startProfilerForTrace(configuration, hub, transactionContext);
    _isProfiling = _profilerReferenceID != nil;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    if (transactionContext.parentSpanId == nil) {
        SENTRY_LOG_DEBUG(
            @"Started root span tracer with id: %@; profilerReferenceId: %@; span id: %@",
            transactionContext.traceId.sentryIdString, _profilerReferenceID.sentryIdString,
            self.spanId.sentrySpanIdString);
    } else {
        SENTRY_LOG_DEBUG(@"Started child span tracer with id: %@; profilerReferenceId: %@; span "
                         @"id: %@; parent span id: %@",
            transactionContext.traceId.sentryIdString, _profilerReferenceID.sentryIdString,
            self.spanId.sentrySpanIdString, transactionContext.parentSpanId.sentrySpanIdString);
    }

    return self;
}

- (void)dealloc
{
#if SENTRY_TARGET_PROFILING_SUPPORTED
    if (self.isProfiling) {
        sentry_discardProfilerCorrelatedToTrace(_profilerReferenceID, self.hub);
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
    [self cancelDeadlineTimeout];
}

- (nullable SentryTracer *)tracer
{
    return self;
}

#pragma mark - Timeouts

- (BOOL)hasIdleTimeout
{
    return _configuration.idleTimeout > 0;
}

- (nullable dispatch_block_t)dispatchBlockCreate:(void (^)(void))block
{
    if ([_dispatchQueue shouldCreateDispatchBlock]) {
        return dispatch_block_create(0, block);
    }
    return NULL;
}

- (void)dispatchCancel:(dispatch_block_t)block
{
    if ([_dispatchQueue shouldDispatchCancel]) {
        dispatch_cancel(block);
    }
}

- (void)startIdleTimeout
{
    __weak SentryTracer *weakSelf = self;
    dispatch_block_t newBlock = [self dispatchBlockCreate:^{
        if (weakSelf == nil) {
            SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not doing anything.");
            return;
        }
        [weakSelf finishInternal];
    }];

    @synchronized(_dispatchTimeoutLock) {
        [self dispatchTimeout:_idleTimeoutBlock
                     newBlock:newBlock
                     interval:_configuration.idleTimeout];
        _idleTimeoutBlock = newBlock;
    }
}

- (void)cancelIdleTimeout
{
    @synchronized(_dispatchTimeoutLock) {
        if ([self hasIdleTimeout]) {
            [self dispatchCancel:_idleTimeoutBlock];
        }
    }
}

- (void)startDeadlineTimeout
{
    __weak SentryTracer *weakSelf = self;
    dispatch_block_t newBlock = [self dispatchBlockCreate:^{
        if (weakSelf == nil) {
            SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not doing anything.");
            return;
        }
        [weakSelf deadlineTimeoutExceeded];
    }];

    @synchronized(_dispatchTimeoutLock) {
        [self dispatchTimeout:_deadlineTimeoutBlock
                     newBlock:newBlock
                     interval:SENTRY_AUTO_TRANSACTION_DEADLINE];
        _deadlineTimeoutBlock = newBlock;
    }
}

- (void)deadlineTimeoutExceeded
{
    SENTRY_LOG_DEBUG(@"Sentry tracer deadline exceeded");
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

    _finishStatus = kSentrySpanStatusDeadlineExceeded;
    [self finishInternal];
}

- (void)cancelDeadlineTimeout
{
    @synchronized(_dispatchTimeoutLock) {
        if (_deadlineTimeoutBlock != NULL) {
            [self dispatchCancel:_deadlineTimeoutBlock];
            _deadlineTimeoutBlock = NULL;
        }
    }
}

- (void)dispatchTimeout:(dispatch_block_t)currentBlock
               newBlock:(dispatch_block_t)newBlock
               interval:(NSTimeInterval)timeInterval
{
    if (currentBlock != NULL) {
        [self dispatchCancel:currentBlock];
    }

    if (newBlock == NULL) {
        SENTRY_LOG_WARN(@"Couldn't create dispatch after block. Finishing transaction.");
        // If the transaction has no children, the SDK will discard it.
        [self finishInternal];
    } else {
        [_dispatchQueue dispatchAfter:timeInterval block:newBlock];
    }
}

#pragma mark - Tracer

- (BOOL)isAutoGeneratedTransaction
{
    return _configuration.waitForChildren || [self hasIdleTimeout];
}

- (id<SentrySpan>)getActiveSpan
{
    id<SentrySpan> span;

    if (self.delegate) {
        @synchronized(_children) {
            span = [self.delegate getActiveSpan];
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
        SENTRY_LOG_WARN(@"Starting a child with operation %@ and description %@ on a finished span "
                        @"is not supported; it won't be sent to Sentry.",
            operation, description);
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

    SENTRY_LOG_DEBUG(@"Checking if tracer %@ (profileReferenceId %@) can be finished",
        self.traceId.sentryIdString, _profilerReferenceID.sentryIdString);
    [self canBeFinished];
}

- (nullable SentryTraceContext *)traceContext
{
    if (_traceContext == nil) {
        @synchronized(self) {
            if (_traceContext == nil) {
                _traceContext = [[SentryTraceContext alloc] initWithTracer:self
                                                                     scope:_hub.scope
                                                                   options:_hub.client.options
                        ?: SentrySDK.options]; // We should remove static classes and always
                                               // inject dependencies.
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

    [self setMeasurement:name measurement:measurement];
}

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value unit:(SentryMeasurementUnit *)unit
{

    SentryMeasurementValue *measurement = [[SentryMeasurementValue alloc] initWithValue:value
                                                                                   unit:unit];
    [self setMeasurement:name measurement:measurement];
}

- (void)setMeasurement:(NSString *)name measurement:(SentryMeasurementValue *)measurement
{
    // Although name is nonnull we saw edge cases where it was nil and then leading to crashes. If
    // the name is nil we can discard the measurement
    if (name == nil) {
        SENTRY_LOG_ERROR(@"The name of the measurement is nil. Discarding the measurement.");
        return;
    }

    @synchronized(_measurements) {
        _measurements[name] = measurement;
    }
}

- (NSDictionary<NSString *, SentryMeasurementValue *> *)measurements
{
    @synchronized(_measurements) {
        return _measurements.copy;
    }
}

- (void)finish
{
    [self finishWithStatus:kSentrySpanStatusOk];
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    SENTRY_LOG_DEBUG(@"Finished trace with tracer profilerReferenceId: %@ and status: %@",
        self.profilerReferenceID.sentryIdString, nameForSentrySpanStatus(status));
    @synchronized(self) {
        self.wasFinishCalled = YES;
    }
    _finishStatus = status;
    [self canBeFinished];
}

- (void)finishForCrash
{
    self.wasFinishCalled = YES;
    _finishStatus = kSentrySpanStatusInternalError;

    // We don't need to clean up during finish cause we're crashing, and the cleanup can execute
    // code that leads to the app hanging and not terminating.
    BOOL discardTransaction = [self finishTracer:kSentrySpanStatusInternalError shouldCleanUp:NO];
    if (discardTransaction) {
        return;
    }

    SentryTransaction *transaction = [self toTransaction];

    [_hub saveCrashTransaction:transaction];
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
            [self startIdleTimeout];
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

    SENTRY_LOG_DEBUG(@"Can finish tracer %@ (profileReferenceId %@)", self.traceId.sentryIdString,
        _profilerReferenceID.sentryIdString);

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
    BOOL discardTransaction = [self finishTracer:kSentrySpanStatusDeadlineExceeded
                                   shouldCleanUp:YES];
    if (discardTransaction) {
        SENTRY_LOG_DEBUG(@"Discarding transaction for trace %@ (profileReferenceId %@)",
            self.traceId.sentryIdString, _profilerReferenceID.sentryIdString);
        return;
    }

    SentryTransaction *transaction = [self toTransaction];

#if SENTRY_TARGET_PROFILING_SUPPORTED
    sentry_stopProfilerDueToFinishedTransaction(
        _hub, _dispatchQueue, transaction, _isProfiling, self.startTimestamp, _startSystemTime
#    if SENTRY_HAS_UIKIT
        ,
        appStartMeasurement
#    endif // SENTRY_HAS_UIKIT
    );
    _isProfiling = NO;
#else
    [_hub captureTransaction:transaction withScope:_hub.scope];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

- (BOOL)finishTracer:(SentrySpanStatus)unfinishedSpansFinishStatus shouldCleanUp:(BOOL)shouldCleanUp
{
    if (shouldCleanUp) {
        [self cancelDeadlineTimeout];
    }

    if (self.isFinished) {
        SENTRY_LOG_DEBUG(@"Tracer %@ was already finished.", _traceContext.traceId.sentryIdString);
        return YES;
    }
    @synchronized(self) {
        if (self.isFinished) {
            SENTRY_LOG_DEBUG(@"Tracer %@ was already finished after synchronizing.",
                _traceContext.traceId.sentryIdString);
            return YES;
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

    if (shouldCleanUp) {
        [self.delegate tracerDidFinish:self];

        if (self.finishCallback) {
            self.finishCallback(self);

            // The callback will only be executed once. No need to keep the reference and we avoid
            // potential retain cycles.
            self.finishCallback = nil;
        }
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
        return YES;
    }

    if (_hub == nil) {
        SENTRY_LOG_DEBUG(
            @"Hub was nil for tracer %@, nothing to do.", _traceContext.traceId.sentryIdString);
        return YES;
    }

    if (shouldCleanUp) {
        id<SentrySpan> _Nullable currentSpan = [_hub.scope span];
        if (currentSpan == self) {
            [_hub.scope setSpan:nil];
        }
    }

    if (self.configuration.finishMustBeCalled && !self.wasFinishCalled) {
        SENTRY_LOG_DEBUG(
            @"Not capturing transaction because finish was not called before timing out.");
        return YES;
    }

    @synchronized(_children) {
        if (_configuration.idleTimeout > 0.0 && _children.count == 0) {
            SENTRY_LOG_DEBUG(@"Was waiting for timeout for UI event trace but it had no children, "
                             @"will not keep transaction.");
            return YES;
        }

        for (id<SentrySpan> span in _children) {
            if (!span.isFinished) {
                [span finishWithStatus:unfinishedSpansFinishStatus];

                // Unfinished children should have the same
                // end timestamp as their parent transaction
                span.timestamp = self.timestamp;
            }
        }

        if ([self isAutoGeneratedTransaction]) {
            [self trimEndTimestamp];
        }
    }

    return NO;
}

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
        transaction.debugMeta =
            [debugImageProvider getDebugImagesFromCacheForFrames:framesOfAllSpans];
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
    if (![self.operation isEqualToString:SentrySpanOperationUiLoad]) {
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

    SENTRY_LOG_DEBUG(@"Returning app start measurements for tracer with profilerReferenceId %@",
        self.profilerReferenceID.sentryIdString);
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
            transaction.debugMeta = [self.debugImageProvider getDebugImagesFromCache];
        }
    }
}

- (void)addFrameStatistics
{
    SentryFramesTracker *framesTracker = SentryDependencyContainer.sharedInstance.framesTracker;
    if (framesTracker.isRunning) {
        CFTimeInterval framesDelay = [framesTracker
                getFramesDelay:self.startSystemTime
            endSystemTimestamp:SentryDependencyContainer.sharedInstance.dateProvider.systemTime]
                                         .delayDuration;

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
