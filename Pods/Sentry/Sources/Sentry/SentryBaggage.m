#import "SentryBaggage.h"
#import "SentryDsn.h"
#import "SentryLogC.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"
#import "SentryTracer.h"
#import "SentryUser.h"

@implementation SentryBaggage

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
#if !SDK_V9
                    userSegment:(nullable NSString *)userSegment
#endif
                     sampleRate:(nullable NSString *)sampleRate
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId
{
    return [self initWithTraceId:traceId
                       publicKey:publicKey
                     releaseName:releaseName
                     environment:environment
                     transaction:transaction
#if !SDK_V9
                     userSegment:userSegment
#endif
                      sampleRate:sampleRate
                      sampleRand:nil
                         sampled:sampled
                        replayId:replayId];
}

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
#if !SDK_V9
                    userSegment:(nullable NSString *)userSegment
#endif
                     sampleRate:(nullable NSString *)sampleRate
                     sampleRand:(nullable NSString *)sampleRand
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId
{

    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _releaseName = releaseName;
        _environment = environment;
        _transaction = transaction;
#if !SDK_V9
        _userSegment = userSegment;
#endif
        _sampleRate = sampleRate;
        _sampleRand = sampleRand;
        _sampled = sampled;
        _replayId = replayId;
    }

    return self;
}

- (NSString *)toHTTPHeaderWithOriginalBaggage:(NSDictionary *_Nullable)originalBaggage
{
    NSMutableDictionary<NSString *, NSString *> *information
        = originalBaggage.mutableCopy ?: [[NSMutableDictionary alloc] init];

    [information setValue:_traceId.sentryIdString forKey:@"sentry-trace_id"];
    [information setValue:_publicKey forKey:@"sentry-public_key"];

    if (_releaseName != nil) {
        [information setValue:_releaseName forKey:@"sentry-release"];
    }

    if (_environment != nil) {
        [information setValue:_environment forKey:@"sentry-environment"];
    }

    if (_transaction != nil) {
        [information setValue:_transaction forKey:@"sentry-transaction"];
    }

#if !SDK_V9
    if (_userSegment != nil) {
        [information setValue:_userSegment forKey:@"sentry-user_segment"];
    }
#endif

    if (_sampleRand != nil) {
        [information setValue:_sampleRand forKey:@"sentry-sample_rand"];
    }

    if (_sampleRate != nil) {
        [information setValue:_sampleRate forKey:@"sentry-sample_rate"];
    }

    if (_sampled != nil) {
        [information setValue:_sampled forKey:@"sentry-sampled"];
    }

    if (_replayId != nil) {
        [information setValue:_replayId forKey:@"sentry-replay_id"];
    }

    return [SentryBaggageSerialization encodeDictionary:information];
}

@end
