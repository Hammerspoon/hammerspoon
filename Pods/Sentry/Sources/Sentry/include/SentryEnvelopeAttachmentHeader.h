#import "SentryAttachment+Private.h"
#import "SentryEnvelopeItemHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeAttachmentHeader : SentryEnvelopeItemHeader

@property (nonatomic, readonly) SentryAttachmentType attachmentType;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                    filename:(NSString *)filename
                 contentType:(NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

@end

NS_ASSUME_NONNULL_END
