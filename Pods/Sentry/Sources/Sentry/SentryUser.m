#import "SentryUser.h"
#import "NSDictionary+SentrySanitize.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryUser

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
        copy.data = self.data.mutableCopy;
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
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];

    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToUser:other];
}

- (BOOL)isEqualToUser:(SentryUser *)user
{
    if (self == user)
        return YES;
    if (user == nil)
        return NO;
    if (self.userId != user.userId && ![self.userId isEqualToString:user.userId])
        return NO;
    if (self.email != user.email && ![self.email isEqualToString:user.email])
        return NO;
    if (self.username != user.username && ![self.username isEqualToString:user.username])
        return NO;
    if (self.ipAddress != user.ipAddress && ![self.ipAddress isEqualToString:user.ipAddress])
        return NO;
    if (self.data != user.data && ![self.data isEqualToDictionary:user.data])
        return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.userId hash];
    hash = hash * 23 + [self.email hash];
    hash = hash * 23 + [self.username hash];
    hash = hash * 23 + [self.ipAddress hash];
    hash = hash * 23 + [self.data hash];

    return hash;
}

@end

NS_ASSUME_NONNULL_END
