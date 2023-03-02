#import "SentryFrame.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryFrame

- (instancetype)init
{
    self = [super init];
    if (self) {
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
    [serializedData setValue:self.inApp forKey:@"in_app"];
    [serializedData setValue:self.stackStart forKey:@"stack_start"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
