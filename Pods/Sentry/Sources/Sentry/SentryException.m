#import "SentryException.h"
#import "SentryThread.h"
#import "SentryMechanism.h"
#import "SentryStacktrace.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryException

- (instancetype)initWithValue:(NSString *)value type:(NSString *)type {
    self = [super init];
    if (self) {
        self.value = value;
        self.type = type;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:self.value forKey:@"value"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:[self.mechanism serialize] forKey:@"mechanism"];
    [serializedData setValue:self.module forKey:@"module"];
    [serializedData setValue:self.thread.threadId forKey:@"thread_id"];
    [serializedData setValue:[self.thread.stacktrace serialize] forKey:@"stacktrace"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
