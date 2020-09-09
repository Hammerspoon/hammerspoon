#import "SentryBreadcrumb.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"

@implementation SentryBreadcrumb

- (instancetype)initWithLevel:(enum SentryLevel)level category:(NSString *)category
{
    self = [super init];
    if (self) {
        self.level = level;
        self.category = category;
        self.timestamp = [NSDate date];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithLevel:kSentryLevelInfo category:@"default"];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:SentryLevelNames[self.level] forKey:@"level"];
    [serializedData setValue:[self.timestamp sentry_toIso8601String] forKey:@"timestamp"];
    [serializedData setValue:self.category forKey:@"category"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];

    return serializedData;
}

@end
