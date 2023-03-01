#import "SentryMechanism.h"
#import "NSDictionary+SentrySanitize.h"
#import "NSMutableDictionary+Sentry.h"
#import "SentryMechanismMeta.h"
#import "SentryNSError.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMechanism

- (instancetype)initWithType:(NSString *)type
{
    self = [super init];
    if (self) {
        self.type = type;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = @{ @"type" : self.type }.mutableCopy;

    [serializedData setBoolValue:self.handled forKey:@"handled"];
    [serializedData setValue:self.synthetic forKey:@"synthetic"];
    [serializedData setValue:self.desc forKey:@"description"];
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];
    [serializedData setValue:self.helpLink forKey:@"help_link"];

    if (nil != self.meta) {
        [serializedData setValue:[self.meta serialize] forKey:@"meta"];
    }

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
