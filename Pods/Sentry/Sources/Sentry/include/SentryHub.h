#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryIntegrationProtocol.h"
#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN
@interface SentryHub : NSObject
SENTRY_NO_INIT

- (instancetype)initWithClient:(SentryClient *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope;

// Since there's no scope stack, single hub instance, experimenting with holding
// session here.
@property (nonatomic, readonly, strong) SentrySession *_Nullable session;

- (void)startSession;
- (void)endSessionWithTimestamp:(NSDate *)timestamp;
- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp;

@property (nonatomic, strong)
    NSMutableArray<NSObject<SentryIntegrationProtocol> *> *installedIntegrations;

/**
 * Captures an SentryEvent
 */
- (NSString *_Nullable)captureEvent:(SentryEvent *)event
                          withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures a NSError
 */
- (NSString *_Nullable)captureError:(NSError *)error
                          withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures a NSException
 */
- (NSString *_Nullable)captureException:(NSException *)exception
                              withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures a Message
 */
- (NSString *_Nullable)captureMessage:(NSString *)message
                            withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(message:scope:));

/**
 * Invokes the callback with a mutable reference to the scope for modifications.
 */
- (void)configureScope:(void (^)(SentryScope *scope))callback;

/**
 * Adds a breadcrumb to the current scope.
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 * Returns a client if there is a bound client on the Hub.
 */
- (SentryClient *_Nullable)getClient;

/**
 * Returns a scope either the current or new.
 */
- (SentryScope *)getScope;

/**
 * Binds a different client to the hub.
 */
- (void)bindClient:(SentryClient *_Nullable)client;

/**
 * Checks if integration is activated for bound client and returns it.
 */
- (id _Nullable)getIntegration:(NSString *)integrationName;

/**
 * Checks if a specific Integration (`integrationClass`) has been installed.
 * @return BOOL If instance of `integrationClass` exists within
 * `SentryHub.installedIntegrations`.
 */
- (BOOL)isIntegrationInstalled:(Class)integrationClass;

/**
 * Set global user -> thus will be sent with every event
 */
- (void)setUser:(SentryUser *_Nullable)user;

@end

NS_ASSUME_NONNULL_END
