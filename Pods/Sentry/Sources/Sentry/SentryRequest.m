#import "SentryRequest.h"
#import "NSDictionary+SentrySanitize.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryRequest

- (instancetype)init
{
    self = [super init];
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    @synchronized(self) {
        if (nil != self.bodySize && self.bodySize.intValue != 0) {
            [serializedData setValue:self.bodySize forKey:@"body_size"];
        }
        [serializedData setValue:self.cookies forKey:@"cookies"];
        [serializedData setValue:self.fragment forKey:@"fragment"];
        if (self.headers != nil) {

            [serializedData setValue:[self.headers sentry_sanitize] forKey:@"headers"];
        }
        [serializedData setValue:self.method forKey:@"method"];
        [serializedData setValue:self.queryString forKey:@"query_string"];
        [serializedData setValue:self.url forKey:@"url"];
    }

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
