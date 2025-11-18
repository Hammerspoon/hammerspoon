#import "SentryFrame.h"
#import "NSMutableDictionary+Sentry.h"
#import "SentryNSDictionarySanitize.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryFrame

- (instancetype)init
{
    if (self = [super init]) {
        self.function = @"<redacted>";
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:self.symbolAddress forKey:@"symbol_addr"];
    [serializedData setValue:self.fileName forKey:@"filename"];
    [serializedData setValue:self.function forKey:@"function"];
    [serializedData setValue:self.module forKey:@"module"];
    [serializedData setValue:self.lineNumber forKey:@"lineno"];
    [serializedData setValue:self.columnNumber forKey:@"colno"];
    [serializedData setValue:self.package forKey:@"package"];
    [serializedData setValue:self.imageAddress forKey:@"image_addr"];
    [serializedData setValue:self.instructionAddress forKey:@"instruction_addr"];
    [serializedData setValue:self.platform forKey:@"platform"];
    [serializedData setValue:self.contextLine forKey:@"context_line"];
    [serializedData setValue:self.preContext forKey:@"pre_context"];
    [serializedData setValue:self.postContext forKey:@"post_context"];
    [serializedData setValue:sentry_sanitize(self.vars) forKey:@"vars"];
    [SentryDictionary setBoolValue:self.inApp forKey:@"in_app" intoDictionary:serializedData];
    [SentryDictionary setBoolValue:self.stackStart
                            forKey:@"stack_start"
                    intoDictionary:serializedData];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
