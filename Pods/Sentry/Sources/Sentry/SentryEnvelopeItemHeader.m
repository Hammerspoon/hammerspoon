#import "SentryEnvelopeItemHeader.h"

@implementation SentryEnvelopeItemHeader

- (instancetype)initWithType:(NSString *)type length:(NSUInteger)length
{
    if (self = [super init]) {
        _type = type;
        _length = length;
    }
    return self;
}

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                 contentType:(NSString *)contentType
{
    if (self = [self initWithType:type length:length]) {
        _contentType = contentType;
    }
    return self;
}

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                   filenname:(NSString *)filename
                 contentType:(NSString *)contentType
{
    if (self = [self initWithType:type length:length contentType:contentType]) {
        _filename = filename;
    }
    return self;
}

- (NSDictionary *)serialize
{

    NSMutableDictionary *target = [[NSMutableDictionary alloc] init];
    if (self.type) {
        [target setValue:self.type forKey:@"type"];
    }

    if (self.filename) {
        [target setValue:self.filename forKey:@"filename"];
    }

    if (self.contentType) {
        [target setValue:self.contentType forKey:@"content_type"];
    }

    [target setValue:[NSNumber numberWithUnsignedInteger:self.length] forKey:@"length"];

    return target;
}

@end
