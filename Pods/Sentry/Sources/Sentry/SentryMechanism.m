#import "SentryMechanism.h"
#import "NSDictionary+SentrySanitize.h"
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

    [serializedData setValue:self.handled forKey:@"handled"];
    [serializedData setValue:self.desc forKey:@"description"];
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];
    [serializedData setValue:self.helpLink forKey:@"help_link"];

    if (nil != self.meta || nil != self.error) {
        NSMutableDictionary<NSString *, id> *meta = [NSMutableDictionary new];
        if (nil != self.meta) {
            [meta addEntriesFromDictionary:self.meta];
        }
        if (nil != self.error) {
            meta[@"ns_error"] = [self.error serialize];
        }
        [serializedData setValue:meta forKey:@"meta"];
    }

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
