#import "SentryHub.h"
#import "SentryClient+Private.h"
#import "SentryCrashAdapter.h"
#import "SentryCurrentDate.h"
#import "SentryFileManager.h"
#import "SentryId.h"
#import "SentryLog.h"
#import "SentrySDK.h"
#import "SentryScope.h"

@interface
SentryHub ()

@property (nonatomic, strong) SentryClient *_Nullable client;
@property (nonatomic, strong) SentryScope *_Nullable scope;
@property (nonatomic, strong) SentryCrashAdapter *sentryCrashWrapper;

@end

@implementation SentryHub {
    NSObject *_sessionLock;
}

@synthesize scope;

- (instancetype)initWithClient:(SentryClient *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
{
    if (self = [super init]) {
        [self bindClient:client];
        self.scope = scope;
        _sessionLock = [[NSObject alloc] init];
        _installedIntegrations = [[NSMutableArray alloc] init];
        self.sentryCrashWrapper = [[SentryCrashAdapter alloc] init];
    }
    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithClient:(SentryClient *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
         andSentryCrashWrapper:(SentryCrashAdapter *)sentryCrashWrapper
{
    self = [self initWithClient:client andScope:scope];
    self.sentryCrashWrapper = sentryCrashWrapper;

    return self;
}

- (void)startSession
{
    SentrySession *lastSession = nil;
    SentryScope *scope = [self getScope];
    SentryClient *client = [self getClient];
    SentryOptions *options = [client options];
    if (nil == options || nil == options.releaseName) {
        [SentryLog
            logWithMessage:[NSString stringWithFormat:@"No option or release to start a session."]
                  andLevel:kSentryLogLevelError];
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
    [lastSession endSessionExitedWithTimestamp:[SentryCurrentDate date]];
    [self captureSession:lastSession];
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
                         andLevel:kSentryLogLevelDebug];
        return;
    }

    [currentSession endSessionExitedWithTimestamp:timestamp];
    [self captureSession:currentSession];
}

- (void)storeCurrentSession:(SentrySession *)session
{
    [[[self getClient] fileManager] storeCurrentSession:session];
}

- (void)deleteCurrentSession
{
    [[[self getClient] fileManager] deleteCurrentSession];
}

- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp
{
    SentryFileManager *fileManager = [[self getClient] fileManager];
    SentrySession *session = [fileManager readCurrentSession];
    if (nil == session) {
        [SentryLog logWithMessage:@"No cached session to close." andLevel:kSentryLogLevelDebug];
        return;
    }
    [SentryLog logWithMessage:@"A cached session was found." andLevel:kSentryLogLevelDebug];

    // Make sure there's a client bound.
    SentryClient *client = [self getClient];
    if (nil == client) {
        [SentryLog logWithMessage:@"No client bound." andLevel:kSentryLogLevelDebug];
        return;
    }

    // The crashed session is handled in SentryCrashIntegration. Checkout the comments there to find
    // out more.
    if (!self.sentryCrashWrapper.crashedLastLaunch) {
        if (nil == timestamp) {
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"No timestamp to close session "
                                                          @"was provided. Closing as abnormal. "
                                                           "Using session's start time %@",
                                         session.started]
                      andLevel:kSentryLogLevelDebug];
            timestamp = session.started;
            [session endSessionAbnormalWithTimestamp:timestamp];
        } else {
            [SentryLog logWithMessage:@"Closing cached session as exited."
                             andLevel:kSentryLogLevelDebug];
            [session endSessionExitedWithTimestamp:timestamp];
        }
        [self deleteCurrentSession];
        [client captureSession:session];
    }
}

- (void)captureSession:(SentrySession *)session
{
    if (nil != session) {
        SentryClient *client = [self getClient];

        if (SentrySDK.logLevel == kSentryLogLevelVerbose) {
            NSData *sessionData = [NSJSONSerialization dataWithJSONObject:[session serialize]
                                                                  options:0
                                                                    error:nil];
            NSString *sessionString = [[NSString alloc] initWithData:sessionData
                                                            encoding:NSUTF8StringEncoding];
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"Capturing session with status: %@",
                                         sessionString]
                      andLevel:kSentryLogLevelDebug];
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
    SentryClient *client = [self getClient];
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
            [client captureEvent:event withSession:crashedSession withScope:self.scope];
            [fileManager deleteCrashedSession];
            return;
        }
    }

    [self captureEvent:event withScope:self.scope];
}

- (SentryId *)captureEvent:(SentryEvent *)event
{
    return [self captureEvent:event withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureEvent:event withScope:scope];
    }
    return SentryId.empty;
}

- (SentryId *)captureMessage:(NSString *)message
{
    return [self captureMessage:message withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    SentryClient *client = [self getClient];
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
    SentryClient *client = [self getClient];
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
    SentryClient *client = [self getClient];

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
    SentryClient *client = [self getClient];
    if (nil != client) {
        [client captureUserFeedback:userFeedback];
    }
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    SentryBeforeBreadcrumbCallback callback = [[[self client] options] beforeBreadcrumb];
    if (nil != callback) {
        crumb = callback(crumb);
    }
    if (nil == crumb) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Discarded Breadcrumb "
                                                             @"in `beforeBreadcrumb`"]
                         andLevel:kSentryLogLevelDebug];
        return;
    }
    [[self getScope] addBreadcrumb:crumb];
}

- (SentryClient *_Nullable)getClient
{
    return self.client;
}

- (SentryScope *)getScope
{
    @synchronized(self) {
        if (self.scope == nil) {
            SentryClient *client = [self getClient];
            if (nil != client) {
                self.scope =
                    [[SentryScope alloc] initWithMaxBreadcrumbs:client.options.maxBreadcrumbs];
            } else {
                self.scope = [[SentryScope alloc] init];
            }
        }
        return self.scope;
    }
}

- (void)bindClient:(SentryClient *_Nullable)client
{
    self.client = client;
}

- (void)configureScope:(void (^)(SentryScope *scope))callback
{
    SentryScope *scope = [self getScope];
    SentryClient *client = [self getClient];
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

- (id _Nullable)getIntegration:(NSString *)integrationName
{
    NSArray *integrations = [self getClient].options.integrations;
    if (![integrations containsObject:integrationName]) {
        return nil;
    }
    return [integrations objectAtIndex:[integrations indexOfObject:integrationName]];
}

/**
 * Set global user -> thus will be sent with every event
 */
- (void)setUser:(SentryUser *_Nullable)user
{
    SentryScope *scope = [self getScope];
    if (nil != scope) {
        [scope setUser:user];
    }
}

@end
