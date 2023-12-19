#import "SentryUser.h"
#import "NSDictionary+SentrySanitize.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUser ()
@property (atomic, strong) NSDictionary<NSString *, id> *_Nullable unknown;
@end

@implementation SentryUser

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        NSMutableDictionary *unknown = [NSMutableDictionary dictionary];
        for (id key in dictionary) {
            id value = [dictionary valueForKey:key];
            if (value == nil) {
                continue;
            }
            BOOL isString = [value isKindOfClass:[NSString class]];
            BOOL isDictionary = [value isKindOfClass:[NSDictionary class]];

            if ([key isEqualToString:@"id"] && isString) {
                self.userId = value;
            } else if ([key isEqualToString:@"email"] && isString) {
                self.email = value;
            } else if ([key isEqualToString:@"username"] && isString) {
                self.username = value;
            } else if ([key isEqualToString:@"ip_address"] && isString) {
                self.ipAddress = value;
            } else if ([key isEqualToString:@"segment"] && isString) {
                self.segment = value;
            } else if ([key isEqualToString:@"data"] && isDictionary) {
                self.data = value;
            } else {
                unknown[key] = value;
            }
        }
        if (unknown.count > 0) {
            self.unknown = [unknown copy];
        }
    }
    return self;
}

- (instancetype)initWithUserId:(NSString *)userId
{
    self = [super init];
    if (self) {
        self.userId = userId;
    }
    return self;
}

- (instancetype)init
{
    return [super init];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    SentryUser *copy = [[SentryUser allocWithZone:zone] init];

    if (copy != nil) {
        copy.userId = self.userId;
        copy.email = self.email;
        copy.username = self.username;
        copy.ipAddress = self.ipAddress;
        copy.segment = self.segment;
        copy.name = self.name;
        copy.geo = self.geo.copy;
        copy.data = self.data.copy;
        copy.unknown = self.unknown.copy;
    }

    return copy;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    [serializedData setValue:self.userId forKey:@"id"];
    [serializedData setValue:self.email forKey:@"email"];
    [serializedData setValue:self.username forKey:@"username"];
    [serializedData setValue:self.ipAddress forKey:@"ip_address"];
    [serializedData setValue:self.segment forKey:@"segment"];
    [serializedData setValue:self.name forKey:@"name"];
    [serializedData setValue:[self.geo serialize] forKey:@"geo"];
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];
    NSDictionary<NSString *, id> *unknown = self.unknown;
    if (unknown != nil) {
        for (id key in unknown) {
            [serializedData setValue:unknown[key] forKey:key];
        }
    }
    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{

    if (other == self) {
        return YES;
    }
    if (!other || ![[other class] isEqual:[self class]]) {
        return NO;
    }

    return [self isEqualToUser:other];
}

- (BOOL)isEqualToUser:(SentryUser *)user
{
    if (self == user) {
        return YES;
    }
    if (user == nil) {
        return NO;
    }

    NSString *otherUserId = user.userId;
    if (self.userId != otherUserId && ![self.userId isEqualToString:otherUserId]) {
        return NO;
    }

    NSString *otherEmail = user.email;
    if (self.email != otherEmail && ![self.email isEqualToString:otherEmail]) {
        return NO;
    }

    NSString *otherUsername = user.username;
    if (self.username != otherUsername && ![self.username isEqualToString:otherUsername]) {
        return NO;
    }

    NSString *otherIpAddress = user.ipAddress;
    if (self.ipAddress != otherIpAddress && ![self.ipAddress isEqualToString:otherIpAddress]) {
        return NO;
    }

    NSString *otherSegment = user.segment;
    if (self.segment != otherSegment && ![self.segment isEqualToString:otherSegment]) {
        return NO;
    }

    NSString *otherName = user.name;
    if (self.name != otherName && ![self.name isEqualToString:otherName]) {
        return NO;
    }

    SentryGeo *otherGeo = user.geo;
    if (self.geo != otherGeo && ![self.geo isEqualToGeo:otherGeo]) {
        return NO;
    }

    NSDictionary<NSString *, id> *otherUserData = user.data;
    if (self.data != otherUserData && ![self.data isEqualToDictionary:otherUserData]) {
        return NO;
    }

    NSDictionary<NSString *, id> *otherUserUnknown = user.unknown;
    if (self.unknown != otherUserUnknown && ![self.unknown isEqualToDictionary:otherUserUnknown]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.userId hash];
    hash = hash * 23 + [self.email hash];
    hash = hash * 23 + [self.username hash];
    hash = hash * 23 + [self.ipAddress hash];
    hash = hash * 23 + [self.segment hash];
    hash = hash * 23 + [self.name hash];
    hash = hash * 23 + [self.geo hash];
    hash = hash * 23 + [self.data hash];
    hash = hash * 23 + [self.unknown hash];
    return hash;
}

@end

NS_ASSUME_NONNULL_END
