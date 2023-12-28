#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDebugMeta.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryException.h"
#import "SentryId.h"
#import "SentryInternalDefines.h"
#import "SentryLevelMapper.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentryRequest.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import "SentryUser.h"

#if SENTRY_HAS_METRIC_KIT
#    import "SentryMechanism.h"
#    import "SentryMetricKitIntegration.h"
#endif // SENTRY_HAS_METRIC_KIT

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEvent

- (instancetype)init
{
    return [self initWithLevel:kSentryLevelNone];
}

- (instancetype)initWithLevel:(enum SentryLevel)level
{
    self = [super init];
    if (self) {
        self.eventId = [[SentryId alloc] init];
        self.level = level;
        self.platform = SentryPlatformName;
        self.timestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
    }
    return self;
}

- (instancetype)initWithError:(NSError *)error
{
    self = [self initWithLevel:kSentryLevelError];
    self.error = error;
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    if (nil == self.timestamp) {
        self.timestamp = [SentryDependencyContainer.sharedInstance.dateProvider date];
    }

    NSMutableDictionary *serializedData = @{
        @"event_id" : self.eventId.sentryIdString,
        @"timestamp" : @(self.timestamp.timeIntervalSince1970),
        @"platform" : SentryPlatformName,
    }
                                              .mutableCopy;

    if (self.level != kSentryLevelNone) {
        [serializedData setValue:nameForSentryLevel(self.level) forKey:@"level"];
    }

    [self addSimpleProperties:serializedData];
    [self addOptionalListProperties:serializedData];

    // This is important here, since we probably use __sentry internal extras
    // before
    [serializedData setValue:[self.extra sentry_sanitize] forKey:@"extra"];
    [serializedData setValue:self.tags forKey:@"tags"];

    return serializedData;
}

- (void)addOptionalListProperties:(NSMutableDictionary *)serializedData
{
    [self addThreads:serializedData];
    [self addExceptions:serializedData];
    [self addDebugImages:serializedData];
}

- (void)addDebugImages:(NSMutableDictionary *)serializedData
{
    NSMutableArray *debugImages = [NSMutableArray new];
    for (SentryDebugMeta *debugImage in self.debugMeta) {
        [debugImages addObject:[debugImage serialize]];
    }
    if (debugImages.count > 0) {
        [serializedData setValue:@{ @"images" : debugImages } forKey:@"debug_meta"];
    }
}

- (void)addExceptions:(NSMutableDictionary *)serializedData
{
    NSMutableArray *exceptions = [NSMutableArray new];
    for (SentryException *exception in self.exceptions) {
        [exceptions addObject:[exception serialize]];
    }
    if (exceptions.count > 0) {
        [serializedData setValue:@{ @"values" : exceptions } forKey:@"exception"];
    }
}

- (void)addThreads:(NSMutableDictionary *)serializedData
{
    NSMutableArray *threads = [NSMutableArray new];
    for (SentryThread *thread in self.threads) {
        [threads addObject:[thread serialize]];
    }
    if (threads.count > 0) {
        [serializedData setValue:@{ @"values" : threads } forKey:@"threads"];
    }
}

- (void)addSimpleProperties:(NSMutableDictionary *)serializedData
{
    [serializedData setValue:[self.sdk sentry_sanitize] forKey:@"sdk"];
    [serializedData setValue:self.releaseName forKey:@"release"];
    [serializedData setValue:self.dist forKey:@"dist"];
    [serializedData setValue:self.environment forKey:@"environment"];

    if (self.transaction) {
        [serializedData setValue:self.transaction forKey:@"transaction"];
    }

    [serializedData setValue:self.fingerprint forKey:@"fingerprint"];

    [serializedData setValue:[self.user serialize] forKey:@"user"];
    [serializedData setValue:self.modules forKey:@"modules"];

    [serializedData setValue:[self.stacktrace serialize] forKey:@"stacktrace"];

    NSMutableArray *breadcrumbs = [self serializeBreadcrumbs];
    if (self.serializedBreadcrumbs.count > 0) {
        [breadcrumbs addObjectsFromArray:self.serializedBreadcrumbs];
    }
    if (breadcrumbs.count > 0) {
        [serializedData setValue:breadcrumbs forKey:@"breadcrumbs"];
    }

    [serializedData setValue:[self.context sentry_sanitize] forKey:@"contexts"];

    if (nil != self.message) {
        [serializedData setValue:[self.message serialize] forKey:@"message"];
    }
    [serializedData setValue:self.logger forKey:@"logger"];
    [serializedData setValue:self.serverName forKey:@"server_name"];
    [serializedData setValue:self.type forKey:@"type"];
    if (nil != self.type && [self.type isEqualToString:@"transaction"]) {
        if (nil != self.startTimestamp) {
            [serializedData setValue:@(self.startTimestamp.timeIntervalSince1970)
                              forKey:@"start_timestamp"];
        } else {
            // start timestamp should never be empty
            [serializedData setValue:@(self.timestamp.timeIntervalSince1970)
                              forKey:@"start_timestamp"];
        }
    }

    if (nil != self.request) {
        [serializedData setValue:[self.request serialize] forKey:@"request"];
    }
}

- (NSMutableArray *)serializeBreadcrumbs
{
    NSMutableArray *crumbs = [NSMutableArray new];
    for (SentryBreadcrumb *crumb in self.breadcrumbs) {
        [crumbs addObject:[crumb serialize]];
    }
    return crumbs;
}

#if SENTRY_HAS_METRIC_KIT

- (BOOL)isMetricKitEvent
{
    if (self.exceptions == nil || self.exceptions.count != 1) {
        return NO;
    }

    NSArray<NSString *> *metricKitMechanisms = @[
        SentryMetricKitDiskWriteExceptionMechanism, SentryMetricKitCpuExceptionMechanism,
        SentryMetricKitHangDiagnosticMechanism, @"MXCrashDiagnostic"
    ];

    SentryException *exception = self.exceptions[0];
    if (exception.mechanism != nil &&
        [metricKitMechanisms containsObject:exception.mechanism.type]) {
        return YES;
    } else {
        return NO;
    }
}

#endif // SENTRY_HAS_METRIC_KIT

@end

NS_ASSUME_NONNULL_END
