#import "SentryHub.h"
#import "SentryClient+Private.h"
#import "SentryCrashAdapter.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryFileManager.h"
#import "SentryId.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentrySamplingContext.h"
#import "SentryScope.h"
#import "SentrySerialization.h"
#import "SentryTracer.h"
#import "SentryTracesSampler.h"
#import "SentryTransaction.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryHub ()

@property (nullable, nonatomic, strong) SentryClient *client;
@property (nullable, nonatomic, strong) SentryScope *scope;
@property (nonatomic, strong) SentryCrashAdapter *crashAdapter;
@property (nonatomic, strong) SentryTracesSampler *sampler;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;

@end

@implementation SentryHub {
    NSObject *_sessionLock;
}

- (instancetype)initWithClient:(nullable SentryClient *)client
                      andScope:(nullable SentryScope *)scope
{
    if (self = [super init]) {
        _client = client;
        _scope = scope;
        _sessionLock = [[NSObject alloc] init];
        _installedIntegrations = [[NSMutableArray alloc] init];
        _crashAdapter = [SentryCrashAdapter sharedInstance];
        _sampler = [[SentryTracesSampler alloc] initWithOptions:client.options];
        _currentDateProvider = [SentryDefaultCurrentDateProvider sharedInstance];
    }
    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithClient:(nullable SentryClient *)client
                      andScope:(nullable SentryScope *)scope
               andCrashAdapter:(SentryCrashAdapter *)crashAdapter
        andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
{
    self = [self initWithClient:client andScope:scope];
    _crashAdapter = crashAdapter;
    _currentDateProvider = currentDateProvider;

    return self;
}

- (void)startSession
{
    SentrySession *lastSession = nil;
    SentryScope *scope = self.scope;
    SentryOptions *options = [_client options];
    if (nil == options || nil == options.releaseName) {
        [SentryLog
            logWithMessage:[NSString stringWithFormat:@"No option or release to start a session."]
                  andLevel:kSentryLevelError];
        return;
    }
    @synchronized(_sessionLock) {
        if (nil != _session) {
            lastSession = _session;
        }
        _session = [[SentrySession alloc] initWithReleaseName:options.releaseName];

        NSString *environment = options.environment;
        if (nil != environment) {
            _session.environment = environment;
        }

        [scope applyToSession:_session];

        [self storeCurrentSession:_session];
        // TODO: Capture outside the lock. Not the reference in the scope.
        [self captureSession:_session];
    }
    [lastSession endSessionExitedWithTimestamp:[self.currentDateProvider date]];
    [self captureSession:lastSession];
}

- (void)endSession
{
    [self endSessionWithTimestamp:[self.currentDateProvider date]];
}

- (void)endSessionWithTimestamp:(NSDate *)timestamp
{
    SentrySession *currentSession = nil;
    @synchronized(_sessionLock) {
        currentSession = _session;
        _session = nil;
        [self deleteCurrentSession];
    }

    if (nil == currentSession) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"No session to end with timestamp."]
                         andLevel:kSentryLevelDebug];
        return;
    }

    [currentSession endSessionExitedWithTimestamp:timestamp];
    [self captureSession:currentSession];
}

- (void)storeCurrentSession:(SentrySession *)session
{
    [[_client fileManager] storeCurrentSession:session];
}

- (void)deleteCurrentSession
{
    [[_client fileManager] deleteCurrentSession];
}

- (void)closeCachedSessionWithTimestamp:(nullable NSDate *)timestamp
{
    SentryFileManager *fileManager = [_client fileManager];
    SentrySession *session = [fileManager readCurrentSession];
    if (nil == session) {
        [SentryLog logWithMessage:@"No cached session to close." andLevel:kSentryLevelDebug];
        return;
    }
    [SentryLog logWithMessage:@"A cached session was found." andLevel:kSentryLevelDebug];

    // Make sure there's a client bound.
    SentryClient *client = _client;
    if (nil == client) {
        [SentryLog logWithMessage:@"No client bound." andLevel:kSentryLevelDebug];
        return;
    }

    // The crashed session is handled in SentryCrashIntegration. Checkout the comments there to find
    // out more.
    if (!self.crashAdapter.crashedLastLaunch) {
        if (nil == timestamp) {
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"No timestamp to close session "
                                                          @"was provided. Closing as abnormal. "
                                                           "Using session's start time %@",
                                         session.started]
                      andLevel:kSentryLevelDebug];
            timestamp = session.started;
            [session endSessionAbnormalWithTimestamp:timestamp];
        } else {
            [SentryLog logWithMessage:@"Closing cached session as exited."
                             andLevel:kSentryLevelDebug];
            [session endSessionExitedWithTimestamp:timestamp];
        }
        [self deleteCurrentSession];
        [client captureSession:session];
    }
}

- (void)captureSession:(SentrySession *)session
{
    if (nil != session) {
        SentryClient *client = _client;

        if (client.options.diagnosticLevel == kSentryLevelDebug) {
            NSData *sessionData = [NSJSONSerialization dataWithJSONObject:[session serialize]
                                                                  options:0
                                                                    error:nil];
            NSString *sessionString = [[NSString alloc] initWithData:sessionData
                                                            encoding:NSUTF8StringEncoding];
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"Capturing session with status: %@",
                                         sessionString]
                      andLevel:kSentryLevelDebug];
        }
        [client captureSession:session];
    }
}

- (SentrySession *)incrementSessionErrors
{
    SentrySession *sessionCopy = nil;
    @synchronized(_sessionLock) {
        if (nil != _session) {
            [_session incrementErrors];
            [self storeCurrentSession:_session];
            sessionCopy = [_session copy];
        }
    }

    return sessionCopy;
}

/**
 * If autoSessionTracking is enabled we want to send the crash and the event together to get proper
 * numbers for release health statistics. If there are multiple crash events to be sent on the start
 * of the SDK there is currently no way to know which one belongs to the crashed session so we just
 * send the session with the first crashed event we receive.
 */
- (void)captureCrashEvent:(SentryEvent *)event
{
    SentryClient *client = _client;
    if (nil == client) {
        return;
    }

    // Check this condition first to avoid unnecessary I/O
    if (client.options.enableAutoSessionTracking) {
        SentryFileManager *fileManager = [client fileManager];
        SentrySession *crashedSession = [fileManager readCrashedSession];

        // It can be that there is no session yet, because autoSessionTracking was just enabled and
        // there is a previous crash on disk. In this case we just send the crash event.
        if (nil != crashedSession) {
            [client captureCrashEvent:event withSession:crashedSession withScope:self.scope];
            [fileManager deleteCrashedSession];
            return;
        }
    }

    [client captureCrashEvent:event withScope:self.scope];
}

- (SentryId *)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope
{
    if (transaction.trace.context.sampled != kSentrySampleDecisionYes)
        return SentryId.empty;
    return [self captureEvent:transaction withScope:scope];
}

- (SentryId *)captureEvent:(SentryEvent *)event
{
    return [self captureEvent:event withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    SentryClient *client = _client;
    if (nil != client) {
        return [client captureEvent:event withScope:scope];
    }
    return SentryId.empty;
}

- (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation
{
    return [self
        startTransactionWithContext:[[SentryTransactionContext alloc] initWithName:name
                                                                         operation:operation]];
}

- (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope
{
    return
        [self startTransactionWithContext:[[SentryTransactionContext alloc] initWithName:name
                                                                               operation:operation]
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
                                 bindToScope:false
                       customSamplingContext:customSamplingContext];
}

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [self startTransactionWithContext:transactionContext
                                 bindToScope:bindToScope
                             waitForChildren:NO
                       customSamplingContext:customSamplingContext];
}

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                              waitForChildren:(BOOL)waitForChildren
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    SentrySamplingContext *samplingContext =
        [[SentrySamplingContext alloc] initWithTransactionContext:transactionContext
                                            customSamplingContext:customSamplingContext];

    transactionContext.sampled = [_sampler sample:samplingContext];

    id<SentrySpan> tracer = [[SentryTracer alloc] initWithTransactionContext:transactionContext
                                                                         hub:self
                                                             waitForChildren:waitForChildren];
    if (bindToScope)
        _scope.span = tracer;

    return tracer;
}

- (SentryId *)captureMessage:(NSString *)message
{
    return [self captureMessage:message withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    SentryClient *client = _client;
    if (nil != client) {
        return [client captureMessage:message withScope:scope];
    }
    return SentryId.empty;
}

- (SentryId *)captureError:(NSError *)error
{
    return [self captureError:error withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    SentrySession *currentSession = [self incrementSessionErrors];
    SentryClient *client = _client;
    if (nil != client) {
        if (nil != currentSession) {
            return [client captureError:error withSession:currentSession withScope:scope];
        } else {
            return [client captureError:error withScope:scope];
        }
    }
    return SentryId.empty;
}

- (SentryId *)captureException:(NSException *)exception
{
    return [self captureException:exception withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    SentrySession *currentSession = [self incrementSessionErrors];

    SentryClient *client = _client;
    if (nil != client) {
        if (nil != currentSession) {
            return [client captureException:exception withSession:currentSession withScope:scope];
        } else {
            return [client captureException:exception withScope:scope];
        }
    }
    return SentryId.empty;
}

- (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    SentryClient *client = _client;
    if (nil != client) {
        [client captureUserFeedback:userFeedback];
    }
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    SentryOptions *options = [[self client] options];
    if (options.maxBreadcrumbs < 1) {
        return;
    }
    SentryBeforeBreadcrumbCallback callback = [options beforeBreadcrumb];
    if (nil != callback) {
        crumb = callback(crumb);
    }
    if (nil == crumb) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Discarded Breadcrumb "
                                                             @"in `beforeBreadcrumb`"]
                         andLevel:kSentryLevelDebug];
        return;
    }
    [self.scope addBreadcrumb:crumb];
}

- (nullable SentryClient *)getClient
{
    return _client;
}

- (void)bindClient:(nullable SentryClient *)client
{
    self.client = client;
}

- (SentryScope *)scope
{
    @synchronized(self) {
        if (_scope == nil) {
            SentryClient *client = _client;
            if (nil != client) {
                _scope = [[SentryScope alloc] initWithMaxBreadcrumbs:client.options.maxBreadcrumbs];
            } else {
                _scope = [[SentryScope alloc] init];
            }
        }
        return _scope;
    }
}

- (void)configureScope:(void (^)(SentryScope *scope))callback
{
    SentryScope *scope = self.scope;
    SentryClient *client = _client;
    if (nil != client && nil != scope) {
        callback(scope);
    }
}

/**
 * Checks if a specific Integration (`integrationClass`) has been installed.
 * @return BOOL If instance of `integrationClass` exists within
 * `SentryHub.installedIntegrations`.
 */
- (BOOL)isIntegrationInstalled:(Class)integrationClass
{
    for (id<SentryIntegrationProtocol> item in SentrySDK.currentHub.installedIntegrations) {
        if ([item isKindOfClass:integrationClass]) {
            return YES;
        }
    }
    return NO;
}

- (nullable id)getIntegration:(NSString *)integrationName
{
    NSArray *integrations = _client.options.integrations;
    if (![integrations containsObject:integrationName]) {
        return nil;
    }
    return [integrations objectAtIndex:[integrations indexOfObject:integrationName]];
}

- (void)setUser:(nullable SentryUser *)user
{
    SentryScope *scope = self.scope;
    if (nil != scope) {
        [scope setUser:user];
    }
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    SentryClient *client = _client;
    if (nil == client) {
        return;
    }

    [client captureEnvelope:[self updateSessionState:envelope]];
}

- (SentryEnvelope *)updateSessionState:(SentryEnvelope *)envelope
{
    if ([self envelopeContainsEventWithErrorOrHigher:envelope.items]) {
        SentrySession *currentSession = [self incrementSessionErrors];

        if (nil != currentSession) {
            // Create a new envelope with the session update
            NSMutableArray<SentryEnvelopeItem *> *itemsToSend =
                [[NSMutableArray alloc] initWithArray:envelope.items];
            [itemsToSend addObject:[[SentryEnvelopeItem alloc] initWithSession:currentSession]];

            return [[SentryEnvelope alloc] initWithHeader:envelope.header items:itemsToSend];
        }
    }

    return envelope;
}

- (BOOL)envelopeContainsEventWithErrorOrHigher:(NSArray<SentryEnvelopeItem *> *)items
{
    for (SentryEnvelopeItem *item in items) {
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeEvent]) {
            // If there is no level the default is error
            SentryLevel level = [SentrySerialization levelFromData:item.data];
            if (level >= kSentryLevelError) {
                return YES;
            }
        }
    }

    return NO;
}

@end

NS_ASSUME_NONNULL_END
