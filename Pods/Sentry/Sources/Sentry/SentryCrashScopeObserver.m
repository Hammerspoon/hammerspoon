#import "SentryLevelMapper.h"
#import <Foundation/Foundation.h>
#import <NSData+Sentry.h>
#import <SentryBreadcrumb.h>
#import <SentryCrashJSONCodec.h>
#import <SentryCrashJSONCodecObjC.h>
#import <SentryCrashScopeObserver.h>
#import <SentryLog.h>
#import <SentryScopeSyncC.h>
#import <SentryUser.h>

@implementation SentryCrashScopeObserver

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
{
    if (self = [super init]) {
        sentrycrash_scopesync_configureBreadcrumbs(maxBreadcrumbs);
    }

    return self;
}

- (void)setUser:(nullable SentryUser *)user
{
    [self syncScope:user
        serialize:^{ return [user serialize]; }
        syncToSentryCrash:^(const void *bytes) { sentrycrash_scopesync_setUser(bytes); }];
}

- (void)setDist:(nullable NSString *)dist
{
    [self syncScope:dist
        serialize:^{ return dist; }
        syncToSentryCrash:^(const void *bytes) { sentrycrash_scopesync_setDist(bytes); }];
}

- (void)setEnvironment:(nullable NSString *)environment
{
    [self syncScope:environment
        serialize:^{ return environment; }
        syncToSentryCrash:^(const void *bytes) { sentrycrash_scopesync_setEnvironment(bytes); }];
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    [self syncScope:context
        syncToSentryCrash:^(const void *bytes) { sentrycrash_scopesync_setContext(bytes); }];
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    [self syncScope:extras
        syncToSentryCrash:^(const void *bytes) { sentrycrash_scopesync_setExtras(bytes); }];
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    [self syncScope:tags
        syncToSentryCrash:^(const void *bytes) { sentrycrash_scopesync_setTags(bytes); }];
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    [self syncScope:fingerprint
        serialize:^{
            NSArray *result = nil;
            if (fingerprint.count > 0) {
                result = fingerprint;
            }
            return result;
        }
        syncToSentryCrash:^(const void *bytes) { sentrycrash_scopesync_setFingerprint(bytes); }];
}

- (void)setLevel:(enum SentryLevel)level
{
    if (level == kSentryLevelNone) {
        sentrycrash_scopesync_setLevel(NULL);
        return;
    }

    NSString *levelAsString = nameForSentryLevel(level);
    NSData *json = [self toJSONEncodedCString:levelAsString];

    sentrycrash_scopesync_setLevel([json bytes]);
}

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb
{
    NSData *json = [self toJSONEncodedCString:crumb];
    if (json == nil) {
        return;
    }

    sentrycrash_scopesync_addBreadcrumb([json bytes]);
}

- (void)clearBreadcrumbs
{
    sentrycrash_scopesync_clearBreadcrumbs();
}

- (void)clear
{
    sentrycrash_scopesync_clear();
}

- (void)syncScope:(NSDictionary *)dict syncToSentryCrash:(void (^)(const void *))syncToSentryCrash
{
    [self syncScope:dict
                serialize:^{
                    NSDictionary *result = nil;
                    if (dict.count > 0) {
                        result = dict;
                    }
                    return result;
                }
        syncToSentryCrash:syncToSentryCrash];
}

- (void)syncScope:(id)object
            serialize:(nullable id (^)(void))serialize
    syncToSentryCrash:(void (^)(const void *))syncToSentryCrash
{
    if (object == nil) {
        syncToSentryCrash(NULL);
        return;
    }

    id serialized = serialize();
    if (serialized == nil) {
        syncToSentryCrash(NULL);
        return;
    }

    NSData *jsonEncodedCString = [self toJSONEncodedCString:serialized];
    if (jsonEncodedCString == nil) {
        return;
    }

    syncToSentryCrash([jsonEncodedCString bytes]);
}

- (nullable NSData *)toJSONEncodedCString:(id)toSerialize
{
    NSError *error = nil;
    NSData *json = nil;
    if (toSerialize != nil) {
        json = [SentryCrashJSONCodec encode:toSerialize
                                    options:SentryCrashJSONEncodeOptionSorted
                                      error:&error];
        if (error != nil) {
            SENTRY_LOG_ERROR(@"Could not serialize %@", error);
            return nil;
        }
    }

    // C strings need to be null terminated
    return [json sentry_nullTerminated];
}

@end
