#import "SentryBaggage.h"
#import "SentryDsn.h"
#import "SentryLog.h"
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
                    userSegment:(nullable NSString *)userSegment
                     sampleRate:(nullable NSString *)sampleRate
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId
{

    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _releaseName = releaseName;
        _environment = environment;
        _transaction = transaction;
        _userSegment = userSegment;
        _sampleRate = sampleRate;
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

    if (_userSegment != nil) {
        [information setValue:_userSegment forKey:@"sentry-user_segment"];
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
