#import "SentryClient+Private.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent+Private.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryInstallation.h"
#import "SentryIntegrationProtocol.h"
#import "SentryLevelMapper.h"
#import "SentryLogC.h"
#import "SentryNSTimerFactory.h"
#import "SentryOptions+Private.h"
#import "SentryPerformanceTracker.h"
#import "SentryProfilingConditionals.h"
#import "SentrySDK+Private.h"
#import "SentrySamplerDecision.h"
#import "SentrySampling.h"
#import "SentrySamplingContext.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
#import "SentrySession+Private.h"
#import "SentrySwift.h"
#import "SentryTraceOrigin.h"
#import "SentryTracer.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext+Private.h"

#if SENTRY_HAS_UIKIT
#    import "SentryUIViewControllerPerformanceTracker.h"
#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryHub ()

@property (nullable, atomic, strong) SentryClient *client;
@property (nullable, nonatomic, strong) SentryScope *scope;
@property (nonatomic) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) NSMutableSet<NSString *> *installedIntegrationNames;
@property (nonatomic) NSUInteger errorsBeforeSession;
@property (nonatomic, weak) id<SentrySessionListener> sessionListener;

@end

@implementation SentryHub {
    NSObject *_sessionLock;
    NSObject *_integrationsLock;
}

- (instancetype)initWithClient:(nullable SentryClient *)client
                      andScope:(nullable SentryScope *)scope
{
    return [self initWithClient:client
                       andScope:scope
                andCrashWrapper:SentryDependencyContainer.sharedInstance.crashWrapper
               andDispatchQueue:SentryDependencyContainer.sharedInstance.dispatchQueueWrapper];
}

/** Internal constructor for testing */
- (instancetype)initWithClient:(nullable SentryClient *)client
                      andScope:(nullable SentryScope *)scope
               andCrashWrapper:(SentryCrashWrapper *)crashWrapper
              andDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
{

    if (self = [super init]) {
        _client = client;
        _scope = scope;
        _crashWrapper = crashWrapper;
        _dispatchQueue = dispatchQueue;
        _sessionLock = [[NSObject alloc] init];
        _integrationsLock = [[NSObject alloc] init];
        _installedIntegrations = [[NSMutableArray alloc] init];
        _installedIntegrationNames = [[NSMutableSet alloc] init];
        _errorsBeforeSession = 0;

        if (_scope) {
            [_crashWrapper enrichScope:_scope];
        }
    }

    return self;
}

- (void)startSession
{
    SentrySession *lastSession = nil;
    SentryScope *scope = self.scope;
    SentryOptions *options = [self.client options];
    if (options == nil) {
        SENTRY_LOG_ERROR(@"Options of the client are nil. Not starting a session.");
        return;
    }
    if (options.releaseName == nil) {
        SENTRY_LOG_ERROR(
            @"Release name of the options of the client is nil. Not starting a session.");
        return;
    }

    @synchronized(_sessionLock) {
        if (_session != nil) {
            lastSession = _session;
        }

        NSString *distinctId =
            [SentryInstallation idWithCacheDirectoryPath:options.cacheDirectoryPath];

        _session = [[SentrySession alloc] initWithReleaseName:options.releaseName
                                                   distinctId:distinctId];

        if (_errorsBeforeSession > 0 && options.enableAutoSessionTracking == YES) {
            _session.errors = _errorsBeforeSession;
            _errorsBeforeSession = 0;
        }

        _session.environment = options.environment;

        [scope applyToSession:_session];

        [self storeCurrentSession:_session];
        [self captureSession:_session];
    }
    [lastSession
        endSessionExitedWithTimestamp:[SentryDependencyContainer.sharedInstance.dateProvider date]];
    [self captureSession:lastSession];

    [_sessionListener sentrySessionStarted:_session];
}

- (void)endSession
{
    [self endSessionWithTimestamp:[SentryDependencyContainer.sharedInstance.dateProvider date]];
}

- (void)endSessionWithTimestamp:(NSDate *)timestamp
{
    SentrySession *currentSession = nil;
    @synchronized(_sessionLock) {
        currentSession = _session;
        _session = nil;
        _errorsBeforeSession = 0;
        [self deleteCurrentSession];
    }

    if (currentSession == nil) {
        SENTRY_LOG_DEBUG(@"No session to end with timestamp.");
        return;
    }
    [currentSession endSessionExitedWithTimestamp:timestamp];
    [self captureSession:currentSession];

    [_sessionListener sentrySessionEnded:currentSession];
}

- (void)storeCurrentSession:(SentrySession *)session
{
    [[self.client fileManager] storeCurrentSession:session];
}

- (void)deleteCurrentSession
{
    [[self.client fileManager] deleteCurrentSession];
}

- (void)closeCachedSessionWithTimestamp:(nullable NSDate *)timestamp
{
    SentryFileManager *fileManager = [self.client fileManager];
    SentrySession *session = [fileManager readCurrentSession];
    if (session == nil) {
        SENTRY_LOG_DEBUG(@"No cached session to close.");
        return;
    }
    SENTRY_LOG_DEBUG(@"A cached session was found.");

    // Make sure there's a client bound.
    SentryClient *client = self.client;
    if (client == nil) {
        SENTRY_LOG_DEBUG(@"No client bound.");
        return;
    }

    // The crashed session is handled in SentryCrashIntegration. Checkout the comments there to find
    // out more.
    if (!self.crashWrapper.crashedLastLaunch) {
        if (timestamp == nil) {
            SENTRY_LOG_DEBUG(@"No timestamp to close session was provided. Closing as abnormal. "
                             @"Using session's start time %@",
                session.started);
            timestamp = session.started;
            [session endSessionAbnormalWithTimestamp:timestamp];
        } else {
            SENTRY_LOG_DEBUG(@"Closing cached session as exited.");
            [session endSessionExitedWithTimestamp:timestamp];
        }
        [self deleteCurrentSession];
        [client captureSession:session];
    }
}

- (void)captureSession:(nullable SentrySession *)session
{
    if (session != nil) {
        SentryClient *client = self.client;

        if (client.options.diagnosticLevel == kSentryLevelDebug) {
            SENTRY_LOG_DEBUG(
                @"Capturing session with status: %@", [self createSessionDebugString:session]);
        }
        [client captureSession:session];
    }
}

- (nullable SentrySession *)incrementSessionErrors
{
    SentrySession *sessionCopy = nil;
    @synchronized(_sessionLock) {
        if (_session != nil) {
            [_session incrementErrors];
            [self storeCurrentSession:_session];
            sessionCopy = [_session copy];
        }
    }

    return sessionCopy;
}

- (void)captureFatalEvent:(SentryEvent *)event
{
    [self captureFatalEvent:event withScope:self.scope];
}

/**
 * We must send the crash and the event together to get proper numbers for release health
 * statistics. If multiple crash events are to be dispatched at the start of the SDK, there is
 * currently no way to know which one belongs to the crashed session, so we send the session with
 * the first crash event we receive.
 */
- (void)captureFatalEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    event.isFatalEvent = YES;

    SentryClient *client = self.client;
    if (client == nil) {
        return;
    }

    SentryFileManager *fileManager = [client fileManager];
    SentrySession *crashedSession = [fileManager readCrashedSession];

    // It can occur that there is no session yet because autoSessionTracking was just enabled or
    // users didn't start a manual session yet, and there is a previous crash on disk. In this case,
    // we just send the crash event.
    if (crashedSession != nil) {
        [client captureFatalEvent:event withSession:crashedSession withScope:scope];
        [fileManager deleteCrashedSession];
    } else {
        [client captureFatalEvent:event withScope:scope];
    }
}

#if SENTRY_HAS_UIKIT

/**
 * This method expects an abnormal session already stored to disk. For more info checkout: @c
 * SentryCrashIntegrationSessionHandler
 */
- (void)captureFatalAppHangEvent:(SentryEvent *)event
{
    // We treat fatal app hang events similar to crashes.
    event.isFatalEvent = YES;

    SentryClient *_Nullable client = _client;
    if (client == nil) {
        return;
    }

    SentryFileManager *fileManager = [client fileManager];
    SentrySession *abnormalSession = [fileManager readAbnormalSession];

    // It can occur that there is no session yet because autoSessionTracking was just enabled or
    // users didn't start a manual session yet, and there is a previous fatal app hang on disk. In
    // this case, we just send the fatal app hang event.
    if (abnormalSession == nil) {
        [client captureFatalEvent:event withScope:self.scope];
        return;
    }

    // Users won't see the anr_foreground mechanism in the UI. The Sentry UI will present release
    // health and session statistics as app hangs.
    abnormalSession.abnormalMechanism = @"anr_foreground";
    [client captureFatalEvent:event withSession:abnormalSession withScope:self.scope];
    [fileManager deleteAbnormalSession];
}

#endif // SENTRY_HAS_UIKIT

- (void)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope
{
    [self captureTransaction:transaction withScope:scope additionalEnvelopeItems:@[]];
}

- (void)captureTransaction:(SentryTransaction *)transaction
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentrySampleDecision decision = transaction.trace.sampled;
    if (decision != kSentrySampleDecisionYes) {
        [self.client recordLostEvent:kSentryDataCategoryTransaction
                              reason:kSentryDiscardReasonSampleRate];
        [self.client recordLostEvent:kSentryDataCategorySpan
                              reason:kSentryDiscardReasonSampleRate
                            quantity:transaction.spans.count + 1];
        return;
    }

    // When a user calls finish on a transaction, which calls captureTransaction, the calling thread
    // here could be the main thread, which we only want to block as long as required. Therefore, we
    // capture the transaction on a background thread.
    __weak SentryHub *weakSelf = self;
    [self.dispatchQueue dispatchAsyncWithBlock:^{
        [weakSelf captureEvent:transaction
                          withScope:scope
            additionalEnvelopeItems:additionalEnvelopeItems];
    }];
}

- (void)saveCrashTransaction:(SentryTransaction *)transaction
{
    SentrySampleDecision decision = transaction.trace.sampled;

    if (decision != kSentrySampleDecisionYes) {
        // No need to update client reports when we're crashing cause they get lost anyways.
        return;
    }

    SentryClient *client = self.client;
    if (client != nil) {
        [client saveCrashTransaction:transaction withScope:self.scope];
    }
}

- (SentryId *)captureEvent:(SentryEvent *)event
{
    return [self captureEvent:event withScope:self.scope];
}

- (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [self captureEvent:event withScope:scope additionalEnvelopeItems:@[]];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentryClient *client = self.client;
    if (client != nil) {
        return [client captureEvent:event
                          withScope:scope
            additionalEnvelopeItems:additionalEnvelopeItems];
    }
    return SentryId.empty;
}

- (void)captureReplayEvent:(SentryReplayEvent *)replayEvent
           replayRecording:(SentryReplayRecording *)replayRecording
                     video:(NSURL *)videoURL
{
    [self.client captureReplayEvent:replayEvent
                    replayRecording:replayRecording
                              video:videoURL
                          withScope:self.scope];
}

- (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation
{
    return [self startTransactionWithContext:[[SentryTransactionContext alloc]
                                                 initWithName:name
                                                   nameSource:kSentryTransactionNameSourceCustom
                                                    operation:operation
                                                       origin:SentryTraceOriginManual]];
}

- (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope
{
    return [self startTransactionWithContext:[[SentryTransactionContext alloc]
                                                 initWithName:name
                                                   nameSource:kSentryTransactionNameSourceCustom
                                                    operation:operation
                                                       origin:SentryTraceOriginManual]
                                 bindToScope:bindToScope];
}

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
{
    return [self startTransactionWithContext:transactionContext customSamplingContext:@{}];
}

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
{
    return [self startTransactionWithContext:transactionContext
                                 bindToScope:bindToScope
                       customSamplingContext:@{}];
}

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [self startTransactionWithContext:transactionContext
                                 bindToScope:NO
                       customSamplingContext:customSamplingContext];
}

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [self startTransactionWithContext:transactionContext
                                 bindToScope:bindToScope
                       customSamplingContext:customSamplingContext
                               configuration:[SentryTracerConfiguration defaultConfiguration]];
}

- (SentryTransactionContext *)transactionContext:(SentryTransactionContext *)context
                                     withSampled:(SentrySampleDecision)sampleDecision
                                      sampleRate:(NSNumber *)sampleRate
                                      sampleRand:(NSNumber *)sampleRand
{
    return [[SentryTransactionContext alloc] initWithName:context.name
                                               nameSource:context.nameSource
                                                operation:context.operation
                                                   origin:context.origin
                                                  traceId:context.traceId
                                                   spanId:context.spanId
                                             parentSpanId:context.parentSpanId
                                                  sampled:sampleDecision
                                            parentSampled:context.parentSampled
                                               sampleRate:sampleRate
                                         parentSampleRate:context.parentSampleRate
                                               sampleRand:sampleRand
                                         parentSampleRand:context.parentSampleRand];
}

- (SentryTracer *)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
                                configuration:(SentryTracerConfiguration *)configuration
{
    SentrySamplingContext *samplingContext =
        [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext
                                            customSamplingContext:customSamplingContext];

    SentrySamplerDecision *tracesSamplerDecision
        = sentry_sampleTrace(samplingContext, self.client.options);
    transactionContext = [self transactionContext:transactionContext
                                      withSampled:tracesSamplerDecision.decision
                                       sampleRate:tracesSamplerDecision.sampleRate
                                       sampleRand:tracesSamplerDecision.sampleRand];

#if SENTRY_TARGET_PROFILING_SUPPORTED
    if (![self.client.options isContinuousProfilingEnabled]) {
        SentrySamplerDecision *profilesSamplerDecision = sentry_sampleTraceProfile(
            samplingContext, tracesSamplerDecision, self.client.options);
        configuration.profilesSamplerDecision = profilesSamplerDecision;
    }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED"

    SentryTracer *tracer = [[SentryTracer alloc] initWithTransactionContext:transactionContext
                                                                        hub:self
                                                              configuration:configuration];

    if (bindToScope)
        self.scope.span = tracer;

    return tracer;
}

- (SentryId *)captureMessage:(NSString *)message
{
    return [self captureMessage:message withScope:self.scope];
}

- (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    SentryClient *client = self.client;
    if (client != nil) {
        return [client captureMessage:message withScope:scope];
    }
    return SentryId.empty;
}

- (SentryId *)captureError:(NSError *)error
{
    return [self captureError:error withScope:self.scope];
}

- (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    SentrySession *currentSession = _session;
    SentryClient *client = self.client;
    if (client != nil) {
        if (currentSession != nil) {
            return [client captureError:error
                              withScope:scope
                 incrementSessionErrors:^(void) { return [self incrementSessionErrors]; }];
        } else {
            _errorsBeforeSession++;
            return [client captureError:error withScope:scope];
        }
    }
    return SentryId.empty;
}

- (SentryId *)captureException:(NSException *)exception
{
    return [self captureException:exception withScope:self.scope];
}

- (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    SentrySession *currentSession = _session;
    SentryClient *client = self.client;
    if (client != nil) {
        if (currentSession != nil) {
            return [client captureException:exception
                                  withScope:scope
                     incrementSessionErrors:^(void) { return [self incrementSessionErrors]; }];
        } else {
            _errorsBeforeSession++;
            return [client captureException:exception withScope:scope];
        }
    }
    return SentryId.empty;
}

#if !SDK_V9
- (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    SentryClient *client = self.client;
    if (client != nil) {
        [client captureUserFeedback:userFeedback];
    }
}
#endif // !SDK_V9

- (void)captureFeedback:(SentryFeedback *)feedback
{
    SentryClient *client = self.client;
    if (client != nil) {
        [client captureFeedback:feedback withScope:self.scope];
    }
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    SentryOptions *options = [[self client] options];
    if (options.maxBreadcrumbs < 1) {
        return;
    }
    SentryBeforeBreadcrumbCallback callback = [options beforeBreadcrumb];
    if (callback != nil) {
        crumb = callback(crumb);
    }
    if (crumb == nil) {
        SENTRY_LOG_DEBUG(@"Discarded Breadcrumb in `beforeBreadcrumb`");
        return;
    }
    [self.scope addBreadcrumb:crumb];
}

- (nullable SentryClient *)getClient
{
    return self.client;
}

- (void)bindClient:(nullable SentryClient *)client
{
    self.client = client;
}

- (SentryScope *)scope
{
    @synchronized(self) {
        if (_scope == nil) {
            SentryClient *client = self.client;
            if (client != nil) {
                _scope = [[SentryScope alloc] initWithMaxBreadcrumbs:client.options.maxBreadcrumbs];
            } else {
                _scope = [[SentryScope alloc] init];
            }

            [_crashWrapper enrichScope:_scope];
        }
        return _scope;
    }
}

- (void)configureScope:(void (^)(SentryScope *scope))callback
{
    SentryScope *scope = self.scope;
    SentryClient *client = _client;
    if (client != nil && scope != nil) {
        callback(scope);
    }
}

/**
 * Checks if a specific Integration (@c integrationClass) has been installed.
 * @return @c YES if instance of @c integrationClass exists within
 * @c SentryHub.installedIntegrations .
 */
- (BOOL)isIntegrationInstalled:(Class)integrationClass
{
    @synchronized(_integrationsLock) {
        for (id<SentryIntegrationProtocol> item in _installedIntegrations) {
            if ([item isKindOfClass:integrationClass]) {
                return YES;
            }
        }
        return NO;
    }
}

- (nullable id<SentryIntegrationProtocol>)getInstalledIntegration:(Class)integrationClass
{
    @synchronized(_integrationsLock) {
        for (id<SentryIntegrationProtocol> item in _installedIntegrations) {
            if ([item isKindOfClass:integrationClass]) {
                return item;
            }
        }
        return nil;
    }
}

- (BOOL)hasIntegration:(NSString *)integrationName
{
    // installedIntegrations and installedIntegrationNames share the same lock.
    // Instead of creating an extra lock object, we use _installedIntegrations.
    @synchronized(_integrationsLock) {
        return [_installedIntegrationNames containsObject:integrationName];
    }
}

- (void)addInstalledIntegration:(id<SentryIntegrationProtocol>)integration name:(NSString *)name
{
    @synchronized(_integrationsLock) {
        [_installedIntegrations addObject:integration];
        [_installedIntegrationNames addObject:name];
    }
}

- (void)removeAllIntegrations
{
    for (NSObject<SentryIntegrationProtocol> *integration in self.installedIntegrations) {
        if ([integration respondsToSelector:@selector(uninstall)]) {
            [integration uninstall];
        }
    }
    @synchronized(_integrationsLock) {
        [_installedIntegrations removeAllObjects];
        [_installedIntegrationNames removeAllObjects];
    }
}

- (NSArray<id<SentryIntegrationProtocol>> *)installedIntegrations
{
    @synchronized(_integrationsLock) {
        return _installedIntegrations.copy;
    }
}

- (NSSet<NSString *> *)installedIntegrationNames
{
    @synchronized(_integrationsLock) {
        return _installedIntegrationNames.copy;
    }
}

- (void)setUser:(nullable SentryUser *)user
{
    SentryScope *scope = self.scope;
    if (scope != nil) {
        [scope setUser:user];
    }
}

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
- (void)storeEnvelope:(SentryEnvelope *)envelope
{
    SentryClient *client = self.client;
    if (client == nil) {
        return;
    }

    // Envelopes are stored only when crash occurs. We should not start a new session when
    // the app is about to crash.
    [client storeEnvelope:[self updateSessionState:envelope startNewSession:NO]];
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    SentryClient *client = self.client;
    if (client == nil) {
        return;
    }

    // If captured envelope cointains not handled errors, these are not going to crash the app and
    // we should create new session.
    [client captureEnvelope:[self updateSessionState:envelope startNewSession:YES]];
}

- (SentryEnvelope *)updateSessionState:(SentryEnvelope *)envelope
                       startNewSession:(BOOL)startNewSession
{
    BOOL handled = YES;
    if ([self envelopeContainsEventWithErrorOrHigher:envelope.items wasHandled:&handled]) {
        SentrySession *currentSession;
        @synchronized(_sessionLock) {
            currentSession = handled ? [self incrementSessionErrors] : [_session copy];
            if (currentSession == nil) {
                return envelope;
            }
            if (!handled) {
                [currentSession
                    endSessionCrashedWithTimestamp:[SentryDependencyContainer.sharedInstance
                                                           .dateProvider date]];
                if (self.client.options.diagnosticLevel == kSentryLevelDebug) {
                    SENTRY_LOG_DEBUG(@"Ending session with status: %@",
                        [self createSessionDebugString:currentSession]);
                }
                if (startNewSession) {
                    // Setting _session to nil so startSession doesn't capture it again
                    _session = nil;
                    [self startSession];
                }
            }
        }

        // Create a new envelope with the session update
        NSMutableArray<SentryEnvelopeItem *> *itemsToSend =
            [[NSMutableArray alloc] initWithArray:envelope.items];
        [itemsToSend addObject:[[SentryEnvelopeItem alloc] initWithSession:currentSession]];
        return [[SentryEnvelope alloc] initWithHeader:envelope.header items:itemsToSend];
    }
    return envelope;
}

- (BOOL)envelopeContainsEventWithErrorOrHigher:(NSArray<SentryEnvelopeItem *> *)items
                                    wasHandled:(BOOL *)handled;
{
    for (SentryEnvelopeItem *item in items) {
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeEvent]) {
            // If there is no level the default is error
            NSDictionary *_Nullable eventJson =
                [SentrySerialization deserializeDictionaryFromJsonData:item.data];
            if (eventJson == nil) {
                return NO;
            }

            SentryLevel level = sentryLevelForString(eventJson[@"level"]);
            if (level >= kSentryLevelError) {
                *handled = [self eventContainsOnlyHandledErrors:eventJson];
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)eventContainsOnlyHandledErrors:(NSDictionary *)eventDictionary
{
    NSArray *exceptions = eventDictionary[@"exception"][@"values"];
    for (NSDictionary *exception in exceptions) {
        NSDictionary *mechanism = exception[@"mechanism"];
        NSNumber *handled = mechanism[@"handled"];

        if (handled != nil && [handled boolValue] == NO) {
            return NO;
        }
    }
    return YES;
}

- (void)reportFullyDisplayed
{
#if SENTRY_HAS_UIKIT
    [[SentryDependencyContainer.sharedInstance uiViewControllerPerformanceTracker]
        reportFullyDisplayed];
#endif // SENTRY_HAS_UIKIT
}

- (NSString *)createSessionDebugString:(SentrySession *)session
{
    if (session == nil) {
        return @"Session is nil.";
    }

    NSData *sessionData = [NSJSONSerialization dataWithJSONObject:[session serialize]
                                                          options:0
                                                            error:nil];
    return [[NSString alloc] initWithData:sessionData encoding:NSUTF8StringEncoding];
}

- (void)flush:(NSTimeInterval)timeout
{
    SentryClient *client = self.client;
    if (client != nil) {
        [client flush:timeout];
    }
}

- (void)close
{
    [self.client close];
    SENTRY_LOG_DEBUG(@"Closed the Hub.");
}

- (void)registerSessionListener:(id<SentrySessionListener>)listener
{
    _sessionListener = listener;
}

- (void)unregisterSessionListener:(id<SentrySessionListener>)listener
{
    if (_sessionListener == listener) {
        _sessionListener = nil;
    }
}

#pragma mark - Protected

- (NSMutableArray<NSString *> *)trimmedInstalledIntegrationNames
{
    NSMutableArray<NSString *> *integrations = [NSMutableArray<NSString *> array];
    for (NSString *integration in SentrySDK.currentHub.installedIntegrationNames) {
        // Every integration starts with "Sentry" and ends with "Integration". To keep the
        // payload of the event small we remove both.
        NSString *withoutSentry = [integration stringByReplacingOccurrencesOfString:@"Sentry"
                                                                         withString:@""];
        NSString *trimmed = [withoutSentry stringByReplacingOccurrencesOfString:@"Integration"
                                                                     withString:@""];
        [integrations addObject:trimmed];
    }
    return integrations;
}

@end

NS_ASSUME_NONNULL_END
