#import "SentryFileContents.h"

@interface
SentryFileContents ()

@end

@implementation SentryFileContents

- (instancetype)initWithPath:(NSString *)path andContents:(NSData *)contents
{
    if (self = [super init]) {
        _path = path;
        _contents = contents;
    }
    return self;
}

@end
