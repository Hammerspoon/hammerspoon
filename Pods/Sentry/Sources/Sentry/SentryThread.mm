#import "SentryThread.h"
#import "NSMutableDictionary+Sentry.h"
#include "SentryProfilingConditionals.h"
#import "SentryStacktrace.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    include "SentryThreadHandle.hpp"
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

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

#if SENTRY_TARGET_PROFILING_SUPPORTED

+ (SentryThread *)threadInfo
{
    const auto threadID = sentry::profiling::ThreadHandle::current()->tid();
    return [[SentryThread alloc] initWithThreadId:@(threadID)];
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

NS_ASSUME_NONNULL_END
