#import "SentryBaggage.h"
#import "SentryDsn.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
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
    }

    return self;
}

- (NSString *)toHTTPHeader
{
    return [self toHTTPHeaderWithOriginalBaggage:nil];
}

- (NSString *)toHTTPHeaderWithOriginalBaggage:(NSDictionary *_Nullable)originalBaggage
{
    NSMutableDictionary *information
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

    return [SentrySerialization baggageEncodedDictionary:information];
}

@end
