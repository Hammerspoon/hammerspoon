#import "SentryTraceState.h"
#import "SentryDsn.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
#import "SentryTracer.h"
#import "SentryUser.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTraceStateUser

- (instancetype)initWithUserId:(nullable NSString *)userId segment:(nullable NSString *)segment
{
    if (self = [super init]) {
        _userId = userId;
        _segment = segment;
    }
    return self;
}

- (instancetype)initWithUser:(nullable SentryUser *)user
{
    NSString *segment;
    if ([user.data[@"segment"] isKindOfClass:[NSString class]]) {
        segment = user.data[@"segment"];
    }

    return [self initWithUserId:user.userId segment:segment];
}

@end

@implementation SentryTraceState

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                           user:(nullable SentryTraceStateUser *)user
{
    if (self = [super init]) {
        _traceId = traceId;
        _publicKey = publicKey;
        _environment = environment;
        _releaseName = releaseName;
        _transaction = transaction;
        _user = user;
    }
    return self;
}

- (nullable instancetype)initWithScope:(SentryScope *)scope options:(SentryOptions *)options
{
    SentryTracer *tracer = [SentryTracer getTracer:scope.span];
    if (tracer == nil) {
        return nil;
    } else {
        return [self initWithTracer:tracer scope:scope options:options];
    }
}

- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(SentryOptions *)options
{
    if (tracer.context.traceId == nil || options.parsedDsn == nil)
        return nil;

    SentryTraceStateUser *stateUser;
    if (scope.userObject != nil)
        stateUser = [[SentryTraceStateUser alloc] initWithUser:scope.userObject];

    return [self initWithTraceId:tracer.context.traceId
                       publicKey:options.parsedDsn.url.user
                     releaseName:options.releaseName
                     environment:options.environment
                     transaction:tracer.name
                            user:stateUser];
}

- (nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)dictionary
{
    SentryId *traceId = [[SentryId alloc] initWithUUIDString:dictionary[@"trace_id"]];
    NSString *publicKey = dictionary[@"public_key"];
    if (traceId == nil || publicKey == nil)
        return nil;

    SentryTraceStateUser *user;
    if (dictionary[@"user"] != nil) {
        NSDictionary *userInfo = dictionary[@"user"];
        user = [[SentryTraceStateUser alloc] initWithUserId:userInfo[@"id"]
                                                    segment:userInfo[@"segment"]];
    }
    return [self initWithTraceId:traceId
                       publicKey:publicKey
                     releaseName:dictionary[@"release"]
                     environment:dictionary[@"environment"]
                     transaction:dictionary[@"transaction"]
                            user:user];
}

- (nullable NSString *)toHTTPHeader
{
    NSError *error;
    NSDictionary *json = [self serialize];
    NSData *data = [SentrySerialization dataWithJSONObject:json error:&error];

    if (nil != error) {
        [SentryLog
            logWithMessage:[NSString stringWithFormat:@"Couldn't encode trace state: %@", error]
                  andLevel:kSentryLevelError];
        return nil;
    }

    // base64 uses `=` as trailing pads, but we need to remove `=`, as `=` is a reserved character
    // in the tracestate header, see
    // https://develop.sentry.dev/sdk/performance/trace-context/#tracestate-headers As base54 only
    // uses `=` as trailing pads we can replace all occurrences.
    NSString *encodedData =
        [[data base64EncodedStringWithOptions:0] stringByReplacingOccurrencesOfString:@"="
                                                                           withString:@""];

    return [NSString stringWithFormat:@"sentry=%@", encodedData];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *result =
        @{ @"trace_id" : _traceId.sentryIdString, @"public_key" : _publicKey }.mutableCopy;

    if (_releaseName != nil)
        [result setValue:_releaseName forKey:@"release"];

    if (_environment != nil)
        [result setValue:_environment forKey:@"environment"];

    if (_transaction != nil)
        [result setValue:_transaction forKey:@"transaction"];

    if (_user != nil) {
        NSMutableDictionary *userDictionary = [[NSMutableDictionary alloc] init];
        if (_user.userId != nil)
            userDictionary[@"id"] = _user.userId;

        if (_user.segment != nil)
            userDictionary[@"segment"] = _user.segment;

        if (userDictionary.count > 0)
            [result setValue:userDictionary forKey:@"user"];
    }

    return result;
}

@end

NS_ASSUME_NONNULL_END
