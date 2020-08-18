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
    SentryUser *user = [[SentryUser allocWithZone:zone] init];
    user.userId = self.userId;
    user.email = self.email;
    user.username = self.username;
    user.data = self.data.mutableCopy;
    return user;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    [serializedData setValue:self.userId forKey:@"id"];
    [serializedData setValue:self.email forKey:@"email"];
    [serializedData setValue:self.username forKey:@"username"];
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
