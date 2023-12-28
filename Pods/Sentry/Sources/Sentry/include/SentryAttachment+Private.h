#import "SentryAttachment.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryAttachmentTypeNameEventAttachment;
FOUNDATION_EXPORT NSString *const kSentryAttachmentTypeNameViewHierarchy;

/**
 * Attachment Type
 */
typedef NS_ENUM(NSInteger, SentryAttachmentType) {
    kSentryAttachmentTypeEventAttachment,
    kSentryAttachmentTypeViewHierarchy
};

NSString *nameForSentryAttachmentType(SentryAttachmentType attachmentType);

SentryAttachmentType typeForSentryAttachmentName(NSString *name);

@interface
SentryAttachment ()
SENTRY_NO_INIT

/**
 * Initializes an attachment with data.
 * @param data The data for the attachment.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is @c "application/octet-stream".
 * @param attachmentType The type of the attachment. Default is @c "EventAttachment".
 */
- (instancetype)initWithData:(NSData *)data
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

/**
 * Initializes an attachment with data.
 * @param path The path of the file whose contents you want to upload to Sentry.
 * @param filename The name of the attachment to display in Sentry.
 * @param contentType The content type of the attachment. Default is @c "application/octet-stream".
 * @param attachmentType The type of the attachment. Default is@c  "EventAttachment".
 */
- (instancetype)initWithPath:(NSString *)path
                    filename:(NSString *)filename
                 contentType:(nullable NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

/**
 * The type of the attachment.
 */
@property (readonly, nonatomic) SentryAttachmentType attachmentType;

@end

NS_ASSUME_NONNULL_END
