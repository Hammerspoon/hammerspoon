#import "SentrySession.h"
#import "NSDate+SentryExtras.h"
#import "SentryCurrentDate.h"
#import "SentryInstallation.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySession

@synthesize flagInit = _init;

/**
 * Default private constructor. We don't name it init to avoid the overlap with the default init of
 * NSObject, which is not available as we specified in the header with SENTRY_NO_INIT.
 */
- (instancetype)initDefault
{
    if (self = [super init]) {
        _sessionId = [NSUUID UUID];
        _started = [SentryCurrentDate date];
        _status = kSentrySessionStatusOk;
        _sequence = 1;
        _errors = 0;
        _distinctId = [SentryInstallation id];
    }

    return self;
}

- (instancetype)initWithReleaseName:(NSString *)releaseName
{
    if (self = [self initDefault]) {
        _init = @YES;
        _releaseName = releaseName;
    }
    return self;
}

- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject
{
    if (self = [super init]) {

        id sid = [jsonObject valueForKey:@"sid"];
        if (sid == nil || ![sid isKindOfClass:[NSString class]])
            return nil;
        NSUUID *sessionId = [[NSUUID UUID] initWithUUIDString:sid];
        if (nil == sessionId)
            return nil;
        _sessionId = sessionId;

        id started = [jsonObject valueForKey:@"started"];
        if (started == nil || ![started isKindOfClass:[NSString class]])
            return nil;
        NSDate *startedDate = [NSDate sentry_fromIso8601String:started];
        if (nil == startedDate) {
            return nil;
        }
        _started = startedDate;

        id status = [jsonObject valueForKey:@"status"];
        if (status == nil || ![status isKindOfClass:[NSString class]])
            return nil;
        if ([@"ok" isEqualToString:status]) {
            _status = kSentrySessionStatusOk;
        } else if ([@"exited" isEqualToString:status]) {
            _status = kSentrySessionStatusExited;
        } else if ([@"crashed" isEqualToString:status]) {
            _status = kSentrySessionStatusCrashed;
        } else if ([@"abnormal" isEqualToString:status]) {
            _status = kSentrySessionStatusAbnormal;
        } else {
            return nil;
        }

        id seq = [jsonObject valueForKey:@"seq"];
        if (seq == nil || ![seq isKindOfClass:[NSNumber class]])
            return nil;
        _sequence = [seq unsignedIntegerValue];

        id errors = [jsonObject valueForKey:@"errors"];
        if (errors == nil || ![errors isKindOfClass:[NSNumber class]])
            return nil;
        _errors = [errors unsignedIntegerValue];

        id did = [jsonObject valueForKey:@"did"];
        if (did == nil || ![did isKindOfClass:[NSString class]])
            return nil;
        _distinctId = did;

        id init = [jsonObject valueForKey:@"init"];
        if ([init isKindOfClass:[NSNumber class]]) {
            _init = init;
        }

        id attrs = [jsonObject valueForKey:@"attrs"];
        if (nil != attrs) {
            id releaseName = [attrs valueForKey:@"release"];
            if ([releaseName isKindOfClass:[NSString class]]) {
                _releaseName = releaseName;
            }

            id environment = [attrs valueForKey:@"environment"];
            if ([environment isKindOfClass:[NSString class]]) {
                _environment = environment;
            }
        }

        id timestamp = [jsonObject valueForKey:@"timestamp"];
        if ([timestamp isKindOfClass:[NSString class]]) {
            _timestamp = [NSDate sentry_fromIso8601String:timestamp];
        }

        id duration = [jsonObject valueForKey:@"duration"];
        if ([duration isKindOfClass:[NSNumber class]]) {
            _duration = duration;
        }
    }

    return self;
}

- (void)setFlagInit
{
    _init = @YES;
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
            @"errors" : @(_errors),
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
            [SentryLog
                logWithMessage:@"Missing string for SessionStatus when serializing SentrySession."
                      andLevel:kSentryLevelWarning];
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
        [serializedData setValue:@(_sequence) forKey:@"seq"];

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

- (id)copyWithZone:(nullable NSZone *)zone
{
    SentrySession *copy = [[[self class] allocWithZone:zone] init];

    if (copy != nil) {
        copy->_sessionId = _sessionId;
        copy->_started = _started;
        copy->_status = _status;
        copy->_errors = _errors;
        copy->_sequence = _sequence;
        copy->_distinctId = _distinctId;
        copy->_timestamp = _timestamp;
        copy->_duration = _duration;
        copy->_releaseName = _releaseName;
        copy.environment = self.environment;
        copy.user = self.user;
        copy->_init = _init;
    }

    return copy;
}

@end

NS_ASSUME_NONNULL_END
