#import "SentryAttachment+Private.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryAttachment

- (instancetype)initWithData:(NSData *)data filename:(NSString *)filename
{
    return [self initWithData:data
                     filename:filename
                  contentType:nil
               attachmentType:kSentryAttachmentTypeEventAttachment];
}

- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
{
    return [self initWithData:data
                     filename:filename
                  contentType:contentType
               attachmentType:kSentryAttachmentTypeEventAttachment];
}

- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType
{

    if (self = [super init]) {
        _data = data;
        _filename = filename;
        _contentType = contentType;
        _attachmentType = attachmentType;
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path
{
    return [self initWithPath:path filename:[path lastPathComponent]];
}

- (instancetype)initWithPath:(NSString *)path filename:(NSString *)filename
{
    return [self initWithPath:path filename:filename contentType:nil];
}

- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
{
    return [self initWithPath:path
                     filename:filename
                  contentType:contentType
               attachmentType:kSentryAttachmentTypeEventAttachment];
}

- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType
{
    if (self = [super init]) {
        _path = path;
        _filename = filename;
        _contentType = contentType;
        _attachmentType = attachmentType;
    }
    return self;
}

@end

NSString *const kSentryAttachmentTypeNameEventAttachment = @"event.attachment";
NSString *const kSentryAttachmentTypeNameViewHierarchy = @"event.view_hierarchy";

NSString *
nameForSentryAttachmentType(SentryAttachmentType attachmentType)
{
    switch (attachmentType) {
    case kSentryAttachmentTypeViewHierarchy:
        return kSentryAttachmentTypeNameViewHierarchy;
    default:
        return kSentryAttachmentTypeNameEventAttachment;
    }
}

SentryAttachmentType
typeForSentryAttachmentName(NSString *name)
{
    if ([name isEqualToString:kSentryAttachmentTypeNameViewHierarchy]) {
        return kSentryAttachmentTypeViewHierarchy;
    }
    return kSentryAttachmentTypeEventAttachment;
}

NS_ASSUME_NONNULL_END
