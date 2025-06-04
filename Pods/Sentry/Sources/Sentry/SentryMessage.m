#import "SentryMessage.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMessage

- (instancetype)initWithFormatted:(NSString *)formatted
{
    if (self = [super init]) {
        _formatted = formatted;
    }
    return self;
}

- (void)setMessage:(NSString *_Nullable)message
{
    _message = message;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    [serializedData setValue:self.formatted forKey:@"formatted"];
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:self.params forKey:@"params"];

    return serializedData;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %@>", [self class], self, [self serialize]];
}

@end

NS_ASSUME_NONNULL_END
