#import "SentryMechanismMeta.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryNSError.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMechanismMeta

- (instancetype)init
{
    self = [super init];
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *data = [NSMutableDictionary new];

    data[@"signal"] = [self.signal sentry_sanitize];
    data[@"mach_exception"] = [self.machException sentry_sanitize];
    data[@"ns_error"] = [self.error serialize];

    return data;
}

@end

NS_ASSUME_NONNULL_END
