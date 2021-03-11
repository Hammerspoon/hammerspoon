#import "SentrySDK.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryCrash.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentryScope.h"

@interface
SentrySDK ()

/**
 holds the current hub instance
 */
@property (class) SentryHub *currentHub;

@end

NS_ASSUME_NONNULL_BEGIN
@implementation SentrySDK

static SentryHub *currentHub;
static BOOL crashedLastRunCalled;

+ (SentryHub *)currentHub
{
    @synchronized(self) {
        if (nil == currentHub) {
            currentHub = [[SentryHub alloc] initWithClient:nil andScope:nil];
        }
        return currentHub;
    }
}

+ (void)setCurrentHub:(SentryHub *)hub
{
    @synchronized(self) {
        currentHub = hub;
    }
}

+ (BOOL)crashedLastRunCalled
{
    return crashedLastRunCalled;
}

+ (void)setCrashedLastRunCalled:(BOOL)value
{
    crashedLastRunCalled = value;
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

/**
 * Set global user -> thus will be sent with every event
 */
+ (void)setUser:(SentryUser *_Nullable)user
{
    [SentrySDK.currentHub setUser:user];
}

#ifndef __clang_analyzer__
// Code not to be analyzed
+ (void)crash
{
    int *p = 0;
    *p = 0;
}
#endif

+ (BOOL)crashedLastRun
{
    return SentryCrash.sharedInstance.crashedLastLaunch;
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

@end

NS_ASSUME_NONNULL_END
