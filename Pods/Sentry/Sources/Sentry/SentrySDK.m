#import "SentrySDK.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryAppStartMeasurement.h"
#import "SentryBreadcrumb.h"
#import "SentryClient+Private.h"
#import "SentryCrash.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentryScope.h"

@interface
SentrySDK ()

@property (class) SentryHub *currentHub;

@end

NS_ASSUME_NONNULL_BEGIN
@implementation SentrySDK

static SentryHub *currentHub;
static BOOL crashedLastRunCalled;
static SentryAppStartMeasurement *sentrySDKappStartMeasurement;
static NSObject *sentrySDKappStartMeasurementLock;

+ (void)initialize
{
    if (self == [SentrySDK class]) {
        sentrySDKappStartMeasurementLock = [[NSObject alloc] init];
    }
}

+ (SentryHub *)currentHub
{
    @synchronized(self) {
        if (nil == currentHub) {
            currentHub = [[SentryHub alloc] initWithClient:nil andScope:nil];
        }
        return currentHub;
    }
}

+ (nullable SentryOptions *)options
{
    @synchronized(self) {
        return [[currentHub getClient] options];
    }
}

/** Internal, only needed for testing. */
+ (void)setCurrentHub:(nullable SentryHub *)hub
{
    @synchronized(self) {
        currentHub = hub;
    }
}

+ (nullable id<SentrySpan>)span
{
    return currentHub.scope.span;
}

+ (BOOL)isEnabled
{
    return currentHub != nil && [currentHub getClient] != nil;
}

+ (BOOL)crashedLastRunCalled
{
    return crashedLastRunCalled;
}

+ (void)setCrashedLastRunCalled:(BOOL)value
{
    crashedLastRunCalled = value;
}

/**
 * Not public, only for internal use.
 */
+ (void)setAppStartMeasurement:(nullable SentryAppStartMeasurement *)value
{
    @synchronized(sentrySDKappStartMeasurementLock) {
        sentrySDKappStartMeasurement = value;
    }
    if (PrivateSentrySDKOnly.onAppStartMeasurementAvailable) {
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable(value);
    }
}

/**
 * Not public, only for internal use.
 */
+ (nullable SentryAppStartMeasurement *)getAppStartMeasurement
{
    @synchronized(sentrySDKappStartMeasurementLock) {
        return sentrySDKappStartMeasurement;
    }
}

+ (void)startWithOptions:(NSDictionary<NSString *, id> *)optionsDict
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:optionsDict
                                                didFailWithError:&error];
    if (nil != error) {
        [SentryLog logWithMessage:@"Error while initializing the SDK" andLevel:kSentryLevelError];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"%@", error]
                         andLevel:kSentryLevelError];
    } else {
        [SentrySDK startWithOptionsObject:options];
    }
}

+ (void)startWithOptionsObject:(SentryOptions *)options
{
    [SentryLog configure:options.debug diagnosticLevel:options.diagnosticLevel];
    SentryClient *newClient = [[SentryClient alloc] initWithOptions:options];
    // The Hub needs to be initialized with a client so that closing a session
    // can happen.
    [SentrySDK setCurrentHub:[[SentryHub alloc] initWithClient:newClient andScope:nil]];
    [SentryLog logWithMessage:[NSString stringWithFormat:@"SDK initialized! Version: %@",
                                        SentryMeta.versionString]
                     andLevel:kSentryLevelDebug];
    [SentrySDK installIntegrations];
}

+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
{
    SentryOptions *options = [[SentryOptions alloc] init];
    configureOptions(options);
    [SentrySDK startWithOptionsObject:options];
}

+ (void)captureCrashEvent:(SentryEvent *)event
{
    [SentrySDK.currentHub captureCrashEvent:event];
}

+ (SentryId *)captureEvent:(SentryEvent *)event
{
    return [SentrySDK captureEvent:event withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScopeBlock:(void (^)(SentryScope *))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureEvent:event withScope:scope];
}

+ (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureEvent:event withScope:scope];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name operation:(NSString *)operation
{
    return [SentrySDK.currentHub startTransactionWithName:name operation:operation];
}

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope
{
    return [SentrySDK.currentHub startTransactionWithName:name
                                                operation:operation
                                              bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext
                                                 bindToScope:bindToScope];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext
                                                 bindToScope:bindToScope
                                       customSamplingContext:customSamplingContext];
}

+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
{
    return [SentrySDK.currentHub startTransactionWithContext:transactionContext
                                       customSamplingContext:customSamplingContext];
}

+ (SentryId *)captureError:(NSError *)error
{
    return [SentrySDK captureError:error withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureError:(NSError *)error withScopeBlock:(void (^)(SentryScope *_Nonnull))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureError:error withScope:scope];
}

+ (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureError:error withScope:scope];
}

+ (SentryId *)captureException:(NSException *)exception
{
    return [SentrySDK captureException:exception withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureException:exception withScope:scope];
}

+ (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureException:exception withScope:scope];
}

+ (SentryId *)captureMessage:(NSString *)message
{
    return [SentrySDK captureMessage:message withScope:SentrySDK.currentHub.scope];
}

+ (SentryId *)captureMessage:(NSString *)message withScopeBlock:(void (^)(SentryScope *))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];
    block(scope);
    return [SentrySDK captureMessage:message withScope:scope];
}

+ (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    return [SentrySDK.currentHub captureMessage:message withScope:scope];
}

/**
 * Needed by hybrid SDKs as react-native to synchronously capture an envelope.
 */
+ (void)captureEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK.currentHub captureEnvelope:envelope];
}

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope
{
    if (nil != [SentrySDK.currentHub getClient]) {
        [[SentrySDK.currentHub getClient] storeEnvelope:envelope];
    }
}

+ (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    [SentrySDK.currentHub captureUserFeedback:userFeedback];
}

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentrySDK.currentHub addBreadcrumb:crumb];
}

+ (void)configureScope:(void (^)(SentryScope *scope))callback
{
    [SentrySDK.currentHub configureScope:callback];
}

+ (void)setUser:(SentryUser *_Nullable)user
{
    [SentrySDK.currentHub setUser:user];
}

+ (BOOL)crashedLastRun
{
    return SentryCrash.sharedInstance.crashedLastLaunch;
}

+ (void)startSession
{
    [SentrySDK.currentHub startSession];
}

+ (void)endSession
{
    [SentrySDK.currentHub endSession];
}

/**
 * Install integrations and keeps ref in `SentryHub.integrations`
 */
+ (void)installIntegrations
{
    if (nil == [SentrySDK.currentHub getClient]) {
        // Gatekeeper
        return;
    }
    SentryOptions *options = [SentrySDK.currentHub getClient].options;
    for (NSString *integrationName in [SentrySDK.currentHub getClient].options.integrations) {
        Class integrationClass = NSClassFromString(integrationName);
        if (nil == integrationClass) {
            NSString *logMessage = [NSString stringWithFormat:@"[SentryHub doInstallIntegrations] "
                                                              @"couldn't find \"%@\" -> skipping.",
                                             integrationName];
            [SentryLog logWithMessage:logMessage andLevel:kSentryLevelError];
            continue;
        } else if ([SentrySDK.currentHub isIntegrationInstalled:integrationClass]) {
            NSString *logMessage =
                [NSString stringWithFormat:@"[SentryHub doInstallIntegrations] already "
                                           @"installed \"%@\" -> skipping.",
                          integrationName];
            [SentryLog logWithMessage:logMessage andLevel:kSentryLevelError];
            continue;
        }
        id<SentryIntegrationProtocol> integrationInstance = [[integrationClass alloc] init];
        [integrationInstance installWithOptions:options];
        [SentryLog
            logWithMessage:[NSString stringWithFormat:@"Integration installed: %@", integrationName]
                  andLevel:kSentryLevelDebug];
        [SentrySDK.currentHub.installedIntegrations addObject:integrationInstance];
    }
}

/**
 * Closes the SDK and uninstalls all the integrations.
 */
+ (void)close
{
    // pop the hub and unset
    SentryHub *hub = SentrySDK.currentHub;
    [SentrySDK setCurrentHub:nil];

    // uninstall all the integrations
    for (NSObject<SentryIntegrationProtocol> *integration in hub.installedIntegrations) {
        if ([integration respondsToSelector:@selector(uninstall)]) {
            [integration uninstall];
        }
    }
    [hub.installedIntegrations removeAllObjects];

    // close the client
    SentryClient *client = [hub getClient];
    client.options.enabled = NO;
    [hub bindClient:nil];

    [SentryLog logWithMessage:@"SDK closed!" andLevel:kSentryLevelDebug];
}

#ifndef __clang_analyzer__
// Code not to be analyzed
+ (void)crash
{
    int *p = 0;
    *p = 0;
}
#endif

@end

NS_ASSUME_NONNULL_END
