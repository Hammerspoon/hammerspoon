#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySDK.h"
#import "SentryLog.h"
#import "SentryCrash.h"
#import "SentryFileManager.h"

@interface SentryHub()

@property (nonatomic, strong) SentryClient *_Nullable client;
@property (nonatomic, strong) SentryScope *_Nullable scope;

@end

@implementation SentryHub {
    NSObject *_sessionLock;
}

@synthesize scope;

- (instancetype)initWithClient:(SentryClient *_Nullable)client andScope:(SentryScope *_Nullable)scope {
    if (self = [super init]) {
        [self bindClient:client];
        self.scope = scope;
        _sessionLock = [[NSObject alloc] init];
    }
    return self;
}

- (void)startSession {
    SentrySession *lastSession = nil;
    SentryScope *scope = [self getScope];
    SentryClient *client = [self getClient];
    SentryOptions *options = [client options];
    if (nil == options || nil == options.releaseName) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"No option or release to start a session."] andLevel:kSentryLogLevelError];
        return;
    }
    @synchronized (_sessionLock) {
        if (nil != _session) {
            lastSession = _session;
        }
        _session = [[SentrySession alloc] init];
        _session.releaseName = options.releaseName;
        [scope applyToSession:_session];

        [self storeCurrentSession:_session];
        // TODO: Capture outside the lock. Not the reference in the scope.
        [self captureSession:_session];
    }
    [lastSession endSessionExitedSessionWithTimestamp:[NSDate date]];
    [self captureSession:lastSession];
}

- (void)endSessionWithTimestamp:(NSDate*)timestamp {
    SentrySession *currentSession = nil;
    @synchronized (_sessionLock) {
        currentSession = _session;
        _session = nil;
        [self deleteCurrentSession];
    }
    
    if (nil == currentSession) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"No session to end with timestamp."] andLevel:kSentryLogLevelDebug];
        return;
    }

    [currentSession endSessionExitedSessionWithTimestamp:timestamp];
    [self captureSession:currentSession];
}

- (void)storeCurrentSession:(SentrySession *)session {
    [[[self getClient] fileManager] storeCurrentSession:session];
}

- (void)deleteCurrentSession {
    [[[self getClient] fileManager] deleteCurrentSession];
}

- (void)closeCachedSession {
    SentryFileManager *fileManager = [[self getClient] fileManager];
    SentrySession *session = [fileManager readCurrentSession];
    if (nil != session) {
        SentryClient *client = [self getClient];
        if (nil != session && nil != client) { // Make sure there's a client bound.
            if (SentryCrash.sharedInstance.crashedLastLaunch) {
                NSDate *lastInForeground = [[NSDate date] dateByAddingTimeInterval:-SentryCrash.sharedInstance.activeDurationSinceLastCrash];
                [SentryLog logWithMessage:[NSString stringWithFormat:@"Closing previous session as crashed."] andLevel:kSentryLogLevelDebug];
                [session endSessionCrashedWithTimestamp:lastInForeground];
            } else {
                [SentryLog logWithMessage:[NSString stringWithFormat:@"Last session did not crash."] andLevel:kSentryLogLevelDebug];
                [session endSessionAbnormalWithTimestamp:session.timestamp];
            }
            [self deleteCurrentSession];
            [client captureSession:session];
        }
    } else {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"No cached session to close."] andLevel:kSentryLogLevelDebug];
    }
}

- (void)captureSession:(SentrySession *)session {
    if (nil != session) {
        SentryClient *client = [self getClient];

        if (SentrySDK.logLevel == kSentryLogLevelVerbose) {
            NSData *sessionData = [NSJSONSerialization dataWithJSONObject:[session serialize] options:0 error:nil];
            NSString *sessionString = [[NSString alloc] initWithData:sessionData encoding:NSUTF8StringEncoding];
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Capturing session with status: %@", sessionString] andLevel:kSentryLogLevelDebug];
        }
        [client captureSession:session];
    }
}

- (void)incrementSessionErrors {
    @synchronized (_sessionLock) {
        if (nil != _session) {
            [_session incrementErrors];
            [self storeCurrentSession:_session];
        }
    }
}

- (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureEvent:event withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureMessage:message withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope {
    [self incrementSessionErrors];
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureError:error withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureException:(NSException *)exception withScope:(SentryScope *_Nullable)scope {
    [self incrementSessionErrors];
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureException:exception withScope:scope];
    }
    return nil;
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    SentryBeforeBreadcrumbCallback callback = [[[self client] options] beforeBreadcrumb];
    if (nil != callback) {
        crumb = callback(crumb);
    }
    if (nil == crumb) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Discarded Breadcrumb in `beforeBreadcrumb`"] andLevel:kSentryLogLevelDebug];
        return;
    }
    [[self getScope] addBreadcrumb:crumb];
}

- (SentryClient *_Nullable)getClient {
    return self.client;
}

- (SentryScope *)getScope {
    @synchronized (self) {
        if (self.scope == nil) {
            SentryClient *client = [self getClient];
            if (nil != client) {
                self.scope = [[SentryScope alloc] initWithMaxBreadcrumbs:client.options.maxBreadcrumbs];
            } else {
                self.scope = [[SentryScope alloc] init];
            }
        }
        return self.scope;
    }
}

- (void)bindClient:(SentryClient * _Nullable)client {
    self.client = client;
}

- (void)configureScope:(void(^)(SentryScope *scope))callback {
    SentryScope *scope = [self getScope];
    SentryClient *client = [self getClient];
    if (nil != client && nil != scope) {
        callback(scope);
    }
}

/**
 * Checks if a specific Integration (`integrationClass`) has been installed.
 * @return BOOL If instance of `integrationClass` exists within `SentryHub.installedIntegrations`.
 */
- (BOOL)isIntegrationInstalled:(Class)integrationClass {
    for (id<SentryIntegrationProtocol> item in SentrySDK.currentHub.installedIntegrations) {
        if ([item isKindOfClass:integrationClass]) {
            return YES;
        }
    }
    return NO;
}

- (id _Nullable)getIntegration:(NSString *)integrationName {
    NSArray *integrations = [self getClient].options.integrations;
    if (![integrations containsObject:integrationName]) {
        return nil;
    }
    return [integrations objectAtIndex:[integrations indexOfObject:integrationName]];
}

/**
 * Set global user -> thus will be sent with every event
 */
- (void)setUser:(SentryUser * _Nullable)user {
    SentryScope *scope = [self getScope];
    if (nil != scope) {
        [scope setUser:user];
    }
}

@end
