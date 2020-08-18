#import "SentrySDK.h"
#import "SentryBreadcrumb.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryClient.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentryScope.h"

static SentryLogLevel logLevel = kSentryLogLevelError;

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

@dynamic logLevel;

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

+ (id)initWithOptions:(NSDictionary<NSString *, id> *)optionsDict
{
    [SentrySDK startWithOptions:optionsDict];
    return nil;
}

+ (id)initWithOptionsObject:(SentryOptions *)options
{
    [SentrySDK startWithOptionsObject:options];
    return nil;
}

+ (void)startWithOptions:(NSDictionary<NSString *, id> *)optionsDict
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:optionsDict
                                                didFailWithError:&error];
    if (nil != error) {
        [SentryLog logWithMessage:@"Error while initializing the SDK"
                         andLevel:kSentryLogLevelError];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"%@", error]
                         andLevel:kSentryLogLevelError];
    } else {
        [SentrySDK startWithOptionsObject:options];
    }
}

+ (void)startWithOptionsObject:(SentryOptions *)options
{
    [self setLogLevel:options.logLevel];
    SentryClient *newClient = [[SentryClient alloc] initWithOptions:options];
    // The Hub needs to be initialized with a client so that closing a session
    // can happen.
    [SentrySDK setCurrentHub:[[SentryHub alloc] initWithClient:newClient andScope:nil]];
    [SentryLog logWithMessage:[NSString stringWithFormat:@"SDK initialized! Version: %@",
                                        SentryMeta.versionString]
                     andLevel:kSentryLogLevelDebug];
    [SentrySDK installIntegrations];
}

+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
{
    SentryOptions *options = [[SentryOptions alloc] init];
    configureOptions(options);
    [SentrySDK startWithOptionsObject:options];
}

+ (NSString *_Nullable)captureEvent:(SentryEvent *)event
{
    return [SentrySDK captureEvent:event withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureEvent:(SentryEvent *)event
                     withScopeBlock:(void (^)(SentryScope *_Nonnull))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureEvent:event withScope:scope];
}

+ (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope
{
    return [SentrySDK.currentHub captureEvent:event withScope:scope];
}

+ (NSString *_Nullable)captureError:(NSError *)error
{
    return [SentrySDK captureError:error withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureError:(NSError *)error
                     withScopeBlock:(void (^)(SentryScope *_Nonnull))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureError:error withScope:scope];
}

+ (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope
{
    return [SentrySDK.currentHub captureError:error withScope:scope];
}

+ (NSString *_Nullable)captureException:(NSException *)exception
{
    return [SentrySDK captureException:exception withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureException:(NSException *)exception
                         withScopeBlock:(void (^)(SentryScope *_Nonnull))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureException:exception withScope:scope];
}

+ (NSString *_Nullable)captureException:(NSException *)exception
                              withScope:(SentryScope *_Nullable)scope
{
    return [SentrySDK.currentHub captureException:exception withScope:scope];
}

+ (NSString *_Nullable)captureMessage:(NSString *)message
{
    return [SentrySDK captureMessage:message withScope:[SentrySDK.currentHub getScope]];
}

+ (NSString *_Nullable)captureMessage:(NSString *)message
                       withScopeBlock:(void (^)(SentryScope *_Nonnull))block
{
    SentryScope *scope = [[SentryScope alloc] initWithScope:[SentrySDK.currentHub getScope]];
    block(scope);
    return [SentrySDK captureMessage:message withScope:scope];
}

+ (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope
{
    return [SentrySDK.currentHub captureMessage:message withScope:scope];
}

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentrySDK.currentHub addBreadcrumb:crumb];
}

+ (void)configureScope:(void (^)(SentryScope *scope))callback
{
    [SentrySDK.currentHub configureScope:callback];
}

+ (void)setLogLevel:(SentryLogLevel)level
{
    NSParameterAssert(level);
    logLevel = level;
}

+ (SentryLogLevel)logLevel
{
    return logLevel;
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
            [SentryLog logWithMessage:logMessage andLevel:kSentryLogLevelError];
            continue;
        } else if ([SentrySDK.currentHub isIntegrationInstalled:integrationClass]) {
            NSString *logMessage =
                [NSString stringWithFormat:@"[SentryHub doInstallIntegrations] already "
                                           @"installed \"%@\" -> skipping.",
                          integrationName];
            [SentryLog logWithMessage:logMessage andLevel:kSentryLogLevelError];
            continue;
        }
        id<SentryIntegrationProtocol> integrationInstance = [[integrationClass alloc] init];
        [integrationInstance installWithOptions:options];
        [SentryLog
            logWithMessage:[NSString stringWithFormat:@"Integration installed: %@", integrationName]
                  andLevel:kSentryLogLevelDebug];
        [SentrySDK.currentHub.installedIntegrations addObject:integrationInstance];
    }
}

@end

NS_ASSUME_NONNULL_END
