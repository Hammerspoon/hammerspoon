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

    @synchronized(self) {
        if (copy != nil) {
            copy.userId = self.userId;
            copy.email = self.email;
            copy.username = self.username;
            copy.ipAddress = self.ipAddress;
            copy.data = self.data.copy;
        }
    }

    return copy;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    @synchronized(self) {
        [serializedData setValue:self.userId forKey:@"id"];
        [serializedData setValue:self.email forKey:@"email"];
        [serializedData setValue:self.username forKey:@"username"];
        [serializedData setValue:self.ipAddress forKey:@"ip_address"];
        [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];
    }

    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{
    @synchronized(self) {
        if (other == self)
            return YES;
        if (!other || ![[other class] isEqual:[self class]])
            return NO;

        return [self isEqualToUser:other];
    }
}

- (BOOL)isEqualToUser:(SentryUser *)user
{
    @synchronized(self) {
        // We need to get some local copies of the properties, because they could be modified during
        // the if statements

        if (self == user)
            return YES;
        if (user == nil)
            return NO;

        NSString *otherUserId = user.userId;
        if (self.userId != otherUserId && ![self.userId isEqualToString:otherUserId])
            return NO;

        NSString *otherEmail = user.email;
        if (self.email != otherEmail && ![self.email isEqualToString:otherEmail])
            return NO;

        NSString *otherUsername = user.username;
        if (self.username != otherUsername && ![self.username isEqualToString:otherUsername])
            return NO;

        NSString *otherIpAdress = user.ipAddress;
        if (self.ipAddress != otherIpAdress && ![self.ipAddress isEqualToString:otherIpAdress])
            return NO;

        NSDictionary<NSString *, id> *otherUserData = user.data;
        if (self.data != otherUserData && ![self.data isEqualToDictionary:otherUserData])
            return NO;
        return YES;
    }
}

- (NSUInteger)hash
{
    @synchronized(self) {
        NSUInteger hash = 17;

        hash = hash * 23 + [self.userId hash];
        hash = hash * 23 + [self.email hash];
        hash = hash * 23 + [self.username hash];
        hash = hash * 23 + [self.ipAddress hash];
        hash = hash * 23 + [self.data hash];

        return hash;
    }
}

@end

NS_ASSUME_NONNULL_END
