#import "SentryMechanismMeta.h"
#import "SentryNSDictionarySanitize.h"
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

    data[@"signal"] = sentry_sanitize(self.signal);
    data[@"mach_exception"] = sentry_sanitize(self.machException);
    data[@"ns_error"] = [self.error serialize];

    return data;
}

@end

NS_ASSUME_NONNULL_END
