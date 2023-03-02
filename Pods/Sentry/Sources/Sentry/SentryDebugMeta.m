#import "SentryDebugMeta.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDebugMeta

- (instancetype)init
{
    return [super init];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:self.uuid forKey:@"uuid"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.imageAddress forKey:@"image_addr"];
    [serializedData setValue:self.imageSize forKey:@"image_size"];
    [serializedData setValue:[self.name lastPathComponent] forKey:@"name"];
    [serializedData setValue:self.imageVmAddress forKey:@"image_vmaddr"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
