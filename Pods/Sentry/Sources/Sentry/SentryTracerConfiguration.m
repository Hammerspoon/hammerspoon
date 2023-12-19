#import "SentryTracerConfiguration.h"

@implementation SentryTracerConfiguration

+ (SentryTracerConfiguration *)defaultConfiguration
{
    return [[SentryTracerConfiguration alloc] init];
}

+ (SentryTracerConfiguration *)configurationWithBlock:(void (^)(SentryTracerConfiguration *))block
{
    SentryTracerConfiguration *result = [[SentryTracerConfiguration alloc] init];

    block(result);

    return result;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.idleTimeout = 0;
        self.waitForChildren = NO;
    }
    return self;
}

@end
