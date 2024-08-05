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
    [SentryDictionary setBoolValue:self.crashed forKey:@"crashed" intoDictionary:serializedData];
    [SentryDictionary setBoolValue:self.current forKey:@"current" intoDictionary:serializedData];
    [serializedData setValue:self.name forKey:@"name"];
    [serializedData setValue:[self.stacktrace serialize] forKey:@"stacktrace"];
    [SentryDictionary setBoolValue:self.isMain forKey:@"main" intoDictionary:serializedData];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
