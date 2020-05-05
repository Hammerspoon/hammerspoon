#import "SentryEvent.h"
#import "SentryBreadcrumb.h"
#import "SentryDebugMeta.h"
#import "SentryClient.h"
#import "SentryUser.h"
#import "SentryThread.h"
#import "SentryException.h"
#import "SentryStacktrace.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryMeta.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEvent

- (instancetype)init {
    return [self initWithLevel:kSentryLevelNone];
}

- (instancetype)initWithLevel:(enum SentryLevel)level {
    self = [super init];
    if (self) {
        self.eventId = [[[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
        self.level = level;
        self.platform = @"cocoa";
    }
    return self;
}

- (instancetype)initWithJSON:(NSData *)json {
    self = [self initWithLevel:kSentryLevelInfo];
    if (self) {
        self.json = json;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize {
    if (nil == self.timestamp) {
        self.timestamp = [NSDate date];
    }
    
    NSMutableDictionary *serializedData = @{
            @"event_id": self.eventId,
            @"timestamp": [self.timestamp sentry_toIso8601String],
            @"platform": @"cocoa",
    }.mutableCopy;
    
    if (self.level != kSentryLevelNone) {
        [serializedData setValue:SentryLevelNames[self.level] forKey:@"level"];
    }
    
    [self addSimpleProperties:serializedData];
    [self addOptionalListProperties:serializedData];
    
    // This is important here, since we probably use __sentry internal extras before
    [serializedData setValue:[self.extra sentry_sanitize] forKey:@"extra"];
    [serializedData setValue:self.tags forKey:@"tags"];

    return serializedData;
}

- (void)addOptionalListProperties:(NSMutableDictionary *)serializedData {
    [self addThreads:serializedData];
    [self addExceptions:serializedData];
    [self addDebugImages:serializedData];
}

- (void)addDebugImages:(NSMutableDictionary *)serializedData {
    NSMutableArray *debugImages = [NSMutableArray new];
    for (SentryDebugMeta *debugImage in self.debugMeta) {
        [debugImages addObject:[debugImage serialize]];
    }
    if (debugImages.count > 0) {
        [serializedData setValue:@{@"images": debugImages} forKey:@"debug_meta"];
    }
}

- (void)addExceptions:(NSMutableDictionary *)serializedData {
    NSMutableArray *exceptions = [NSMutableArray new];
    for (SentryException *exception in self.exceptions) {
        [exceptions addObject:[exception serialize]];
    }
    if (exceptions.count > 0) {
        [serializedData setValue:@{@"values": exceptions} forKey:@"exception"];
    }
}

- (void)addThreads:(NSMutableDictionary *)serializedData {
    NSMutableArray *threads = [NSMutableArray new];
    for (SentryThread *thread in self.threads) {
        [threads addObject:[thread serialize]];
    }
    if (threads.count > 0) {
        [serializedData setValue:@{@"values": threads} forKey:@"threads"];
    }
}

- (void)addSdkInformation:(NSMutableDictionary *)serializedData {
    // If sdk was set, we don't take the default
    if (nil != self.sdk) {
        serializedData[@"sdk"] = self.sdk;
        return;
    }
    NSMutableDictionary *sdk = @{
                                 @"name": SentryMeta.sdkName,
                                 @"version": SentryMeta.versionString
                                 }.mutableCopy;
    if (self.extra[@"__sentry_sdk_integrations"]) {
        [sdk setValue:self.extra[@"__sentry_sdk_integrations"] forKey:@"integrations"];
    }
    serializedData[@"sdk"] = sdk;
}

- (void)addSimpleProperties:(NSMutableDictionary *)serializedData {
    [self addSdkInformation:serializedData];
    [serializedData setValue:self.releaseName forKey:@"release"];
    [serializedData setValue:self.dist forKey:@"dist"];
    [serializedData setValue:self.environment forKey:@"environment"];
    
    if (self.transaction) {
        [serializedData setValue:self.transaction forKey:@"transaction"];
    } else if (self.extra[@"__sentry_transaction"]) {
        [serializedData setValue:self.extra[@"__sentry_transaction"] forKey:@"transaction"];
    }
    
    [serializedData setValue:self.fingerprint forKey:@"fingerprint"];
    
    [serializedData setValue:[self.user serialize] forKey:@"user"];
    [serializedData setValue:self.modules forKey:@"modules"];
    
    [serializedData setValue:[self.stacktrace serialize] forKey:@"stacktrace"];
    
    [serializedData setValue:[self serializeBreadcrumbs] forKey:@"breadcrumbs"];
    
    [serializedData setValue:self.context forKey:@"contexts"];

    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:self.logger forKey:@"logger"];
    [serializedData setValue:self.serverName forKey:@"server_name"];
    [serializedData setValue:self.type forKey:@"type"];
    if (nil != self.type && [self.type isEqualToString:@"transaction"]) {
        if (nil != self.startTimestamp) {
            [serializedData setValue:[self.startTimestamp sentry_toIso8601String] forKey:@"start_timestamp"];
        } else {
            // start timestamp should never be empty
            [serializedData setValue:[self.timestamp sentry_toIso8601String] forKey:@"start_timestamp"];
        }
        
    }
}

- (NSMutableArray *_Nullable)serializeBreadcrumbs {
    NSMutableArray *crumbs = [NSMutableArray new];
    for (SentryBreadcrumb *crumb in self.breadcrumbs) {
        [crumbs addObject:[crumb serialize]];
    }
    if (crumbs.count <= 0) {
        return nil;
    }
    return crumbs;
}

@end

NS_ASSUME_NONNULL_END
