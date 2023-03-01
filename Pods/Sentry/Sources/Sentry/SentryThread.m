#import "SentryThread.h"
#import "NSMutableDictionary+Sentry.h"
#import "SentryStacktrace.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryThread

- (instancetype)initWithThreadId:(NSNumber *)threadId
{
    self = [super init];
    if (self) {
        self.threadId = threadId;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData =
        @{ @"id" : self.threadId ? self.threadId : @(99) }.mutableCopy;

    [serializedData setBoolValue:self.crashed forKey:@"crashed"];
    [serializedData setBoolValue:self.current forKey:@"current"];
    [serializedData setValue:self.name forKey:@"name"];
    [serializedData setValue:[self.stacktrace serialize] forKey:@"stacktrace"];
    [serializedData setBoolValue:self.isMain forKey:@"main"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
