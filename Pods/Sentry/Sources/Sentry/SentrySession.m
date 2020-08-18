#import "SentrySession.h"
#import "NSDate+SentryExtras.h"
#import "SentryCurrentDate.h"
#import "SentryInstallation.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySession

@synthesize flagInit = _init;

- (instancetype)initWithReleaseName:(NSString *)releaseName
{
    if (self = [super init]) {
        _sessionId = [NSUUID UUID];
        _started = [SentryCurrentDate date];
        _status = kSentrySessionStatusOk;
        _sequence = 1;
        _errors = 0;
        _init = @YES;
        _distinctId = [SentryInstallation id];
        _releaseName = releaseName;
    }
    return self;
}

- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject
{
    // Note this doesn't use the main init method since it should only init
    // fields that exist in the JSON.
    if (self = [super init]) {
        _sessionId = [[NSUUID UUID] initWithUUIDString:[jsonObject valueForKey:@"sid"]];
        _distinctId = [jsonObject valueForKey:@"did"];
        NSString *startedString = [jsonObject valueForKey:@"started"];
        if (nil != startedString) {
            _started = [NSDate sentry_fromIso8601String:startedString];
        }
        NSString *timestampString = [jsonObject valueForKey:@"timestamp"];
        if (nil != timestampString) {
            _timestamp = [NSDate sentry_fromIso8601String:timestampString];
        }
        NSString *status = [jsonObject valueForKey:@"status"];
        if ([@"ok" isEqualToString:status]) {
            _status = kSentrySessionStatusOk;
        } else if ([@"exited" isEqualToString:status]) {
            _status = kSentrySessionStatusExited;
        } else if ([@"crashed" isEqualToString:status]) {
            _status = kSentrySessionStatusCrashed;
        } else if ([@"abnormal" isEqualToString:status]) {
            _status = kSentrySessionStatusAbnormal;
        }
        _sequence = [[jsonObject valueForKey:@"seq"] unsignedIntegerValue];
        _errors = [[jsonObject valueForKey:@"errors"] unsignedIntegerValue];
        id init = [jsonObject valueForKey:@"init"];
        if (nil != init) {
            _init = init;
        }
        NSNumber *duration = [jsonObject valueForKey:@"duration"];
        if (nil != duration) {
            _duration = duration;
        }
        id attrs = [jsonObject valueForKey:@"attrs"];
        if (nil != attrs) {
            _releaseName = [attrs valueForKey:@"release"];
            _environment = [attrs valueForKey:@"environment"];
        }
    }
    return self;
}

- (void)endSessionExitedWithTimestamp:(NSDate *)timestamp
{
    @synchronized(self) {
        [self changed];
        _status = kSentrySessionStatusExited;
        [self endSessionWithTimestamp:timestamp];
    }
}

- (void)endSessionCrashedWithTimestamp:(NSDate *)timestamp
{
    @synchronized(self) {
        [self changed];
        _status = kSentrySessionStatusCrashed;
        [self endSessionWithTimestamp:timestamp];
    }
}

- (void)endSessionAbnormalWithTimestamp:(NSDate *)timestamp
{
    @synchronized(self) {
        [self changed];
        _status = kSentrySessionStatusAbnormal;
        [self endSessionWithTimestamp:timestamp];
    }
}

- (void)endSessionWithTimestamp:(NSDate *)timestamp
{
    @synchronized(self) {
        _timestamp = timestamp;
        NSTimeInterval secondsBetween = [_timestamp timeIntervalSinceDate:_started];
        _duration = [NSNumber numberWithDouble:secondsBetween];
    }
}

- (void)changed
{
    _init = nil;
    _sequence++;
}

- (void)incrementErrors
{
    @synchronized(self) {
        [self changed];
        _errors++;
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    @synchronized(self) {
        NSMutableDictionary *serializedData = @{
            @"sid" : _sessionId.UUIDString,
            @"errors" : [NSNumber numberWithLong:_errors],
            @"started" : [_started sentry_toIso8601String],
        }
                                                  .mutableCopy;

        if (nil != _init) {
            [serializedData setValue:_init forKey:@"init"];
        }

        NSString *statusString = nil;
        switch (_status) {
        case kSentrySessionStatusOk:
            statusString = @"ok";
            break;
        case kSentrySessionStatusExited:
            statusString = @"exited";
            break;
        case kSentrySessionStatusCrashed:
            statusString = @"crashed";
            break;
        case kSentrySessionStatusAbnormal:
            statusString = @"abnormal";
            break;
        default:
            // TODO: Log warning
            break;
        }

        if (nil != statusString) {
            [serializedData setValue:statusString forKey:@"status"];
        }

        NSDate *timestamp = nil != _timestamp ? _timestamp : [SentryCurrentDate date];
        [serializedData setValue:[timestamp sentry_toIso8601String] forKey:@"timestamp"];

        if (nil != _duration) {
            [serializedData setValue:_duration forKey:@"duration"];
        } else if (nil == _init) {
            NSTimeInterval secondsBetween = [_timestamp timeIntervalSinceDate:_started];
            [serializedData setValue:[NSNumber numberWithDouble:secondsBetween] forKey:@"duration"];
        }

        // TODO: seq to be just unix time in mills?
        [serializedData setValue:[NSNumber numberWithLong:_sequence] forKey:@"seq"];

        if (nil != _releaseName || nil != _environment) {
            NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];
            if (nil != _releaseName) {
                [attrs setValue:_releaseName forKey:@"release"];
            }

            if (nil != _environment) {
                [attrs setValue:_environment forKey:@"environment"];
            }
            [serializedData setValue:attrs forKey:@"attrs"];
        }

        [serializedData setValue:_distinctId forKey:@"did"];

        return serializedData;
    }
}

@end

NS_ASSUME_NONNULL_END
