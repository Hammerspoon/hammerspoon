#import "SentryMessage.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

const NSUInteger MAX_STRING_LENGTH = 8192;

@implementation SentryMessage

- (instancetype)initWithFormatted:(NSString *)formatted
{
    if (self = [super init]) {
        if (nil != formatted && formatted.length > MAX_STRING_LENGTH) {
            _formatted = [formatted substringToIndex:MAX_STRING_LENGTH];
        } else {
            _formatted = formatted;
        }
    }
    return self;
}

- (void)setMessage:(NSString *_Nullable)message
{
    if (nil != message && message.length > MAX_STRING_LENGTH) {
        _message = [message substringToIndex:MAX_STRING_LENGTH];
    } else {
        _message = message;
    }
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
