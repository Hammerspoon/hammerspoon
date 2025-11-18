#import "SentryWatchdogTerminationScopeObserver.h"

#if SENTRY_HAS_UIKIT

#    import <SentryBreadcrumb.h>
#    import <SentryFileManager.h>
#    import <SentryLogC.h>
#    import <SentrySwift.h>
#    import <SentryWatchdogTerminationBreadcrumbProcessor.h>

@interface SentryWatchdogTerminationScopeObserver ()

@property (nonatomic, strong) SentryWatchdogTerminationBreadcrumbProcessor *breadcrumbProcessor;
@property (nonatomic, strong) SentryWatchdogTerminationAttributesProcessor *attributesProcessor;

@end

@implementation SentryWatchdogTerminationScopeObserver

- (instancetype)
    initWithBreadcrumbProcessor:(SentryWatchdogTerminationBreadcrumbProcessor *)breadcrumbProcessor
            attributesProcessor:(SentryWatchdogTerminationAttributesProcessor *)attributesProcessor;
{
    if (self = [super init]) {
        self.breadcrumbProcessor = breadcrumbProcessor;
        self.attributesProcessor = attributesProcessor;
    }

    return self;
}

// PRAGMA MARK: - SentryScopeObserver

- (void)clear
{
    [self.breadcrumbProcessor clear];
    [self.attributesProcessor clear];
}

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb
{
    [self.breadcrumbProcessor addSerializedBreadcrumb:crumb];
}

- (void)clearBreadcrumbs
{
    [self.breadcrumbProcessor clearBreadcrumbs];
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    [self.attributesProcessor setContext:context];
}

- (void)setDist:(nullable NSString *)dist
{
    [self.attributesProcessor setDist:dist];
}

- (void)setEnvironment:(nullable NSString *)environment
{
    [self.attributesProcessor setEnvironment:environment];
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    [self.attributesProcessor setExtras:extras];
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    [self.attributesProcessor setFingerprint:fingerprint];
}

- (void)setLevel:(enum SentryLevel)level
{
    // Nothing to do here, watchdog termination events are always Fatal
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    [self.attributesProcessor setTags:tags];
}

- (void)setUser:(nullable SentryUser *)user
{
    [self.attributesProcessor setUser:user];
}

- (void)setTraceContext:(nullable NSDictionary<NSString *, id> *)traceContext
{
    // Nothing to do here, Trace Context is not persisted for watchdog termination events
    // On regular events, we have the current trace in memory, but there isn't time to persist one
    // in watchdog termination events
}

@end

#endif // SENTRY_HAS_UIKIT
