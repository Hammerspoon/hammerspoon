#import "SentryAttachment.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const DefaultContentType = @"application/octet-stream";

@implementation SentryAttachment

- (instancetype)initWithData:(NSData *)data filename:(NSString *)filename
{
    return [self initWithData:data filename:filename contentType:DefaultContentType];
}

- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(NSString *)contentType
{

    if (self = [super init]) {
        _data = data;
        _filename = filename;
        _contentType = contentType;
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path
{
    return [self initWithPath:path filename:[path lastPathComponent]];
}

- (instancetype)initWithPath:(NSString *)path filename:(NSString *)filename
{
    return [self initWithPath:path filename:filename contentType:DefaultContentType];
}

- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(NSString *)contentType
{
    if (self = [super init]) {
        _path = path;
        _filename = filename;
        _contentType = contentType;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
