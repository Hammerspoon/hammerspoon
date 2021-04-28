#import "SentryEnvelope.h"
#import "SentryAttachment.h"
#import "SentryBreadcrumb.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryLog.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentrySdkInfo.h"
#import "SentrySerialization.h"
#import "SentrySession.h"
#import "SentryTransaction.h"
#import "SentryUserFeedback.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEnvelopeHeader

// id can be null if no event in the envelope or attachment related to event
- (instancetype)initWithId:(SentryId *_Nullable)eventId
{
    SentrySdkInfo *sdkInfo = [[SentrySdkInfo alloc] initWithName:SentryMeta.sdkName
                                                      andVersion:SentryMeta.versionString];
    self = [self initWithId:eventId andSdkInfo:sdkInfo];

    return self;
}

- (instancetype)initWithId:(SentryId *_Nullable)eventId andSdkInfo:(SentrySdkInfo *_Nullable)sdkInfo
{
    if (self = [super init]) {
        _eventId = eventId;
        _sdkInfo = sdkInfo;
    }

    return self;
}

@end

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
                   filenname:(NSString *)filename
                 contentType:(NSString *)contentType
{
    if (self = [self initWithType:type length:length]) {
        _filename = filename;
        _contentType = contentType;
    }
    return self;
}

@end

@implementation SentryEnvelopeItem

- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header data:(NSData *)data
{
    if (self = [super init]) {
        _header = header;
        _data = data;
    }
    return self;
}

- (instancetype)initWithEvent:(SentryEvent *)event
{
    NSError *error;
    NSData *json = [SentrySerialization dataWithJSONObject:[event serialize] error:&error];

    if (nil != error) {
        // It could be the user added something to the context or the sdk that can't serialized.
        event.context = nil;
        event.sdk = nil;
        error = nil;
        json = [SentrySerialization dataWithJSONObject:[event serialize] error:&error];

        // The context or the sdk was the problem for serialization. Add a breadcrumb that we are
        // dropping the context and the sdk.
        if (nil == error) {
            NSMutableArray<SentryBreadcrumb *> *breadcrumbs = [event.breadcrumbs mutableCopy];
            if (nil == breadcrumbs) {
                breadcrumbs = [[NSMutableArray alloc] init];
            }

            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelError
                                                                     category:@"sentry.event"];
            crumb.message = @"A value set to the context or sdk is not serializable. Dropping "
                            @"context and sdk.";
            crumb.type = @"error";
            [breadcrumbs addObject:crumb];
            event.breadcrumbs = breadcrumbs;

            json = [SentrySerialization dataWithJSONObject:[event serialize] error:nil];
        } else {
            // We don't know what caused the serialization to fail.
            SentryEvent *errorEvent = [[SentryEvent alloc] initWithLevel:kSentryLevelWarning];

            // Add some context to the event. We can only set simple properties otherwise we
            // risk that the conversion fails again.
            NSString *message =
                [NSString stringWithFormat:@"JSON conversion error for event with message: '%@'",
                          event.message];

            errorEvent.message = [[SentryMessage alloc] initWithFormatted:message];
            errorEvent.releaseName = event.releaseName;
            errorEvent.environment = event.environment;
            errorEvent.platform = event.platform;
            errorEvent.timestamp = event.timestamp;

            // We accept the risk that this simple serialization fails. Therefore we ignore the
            // error on purpose.
            json = [SentrySerialization dataWithJSONObject:[errorEvent serialize] error:nil];
        }
    }

    // event.type can be nil and the server infers error if there's a stack trace, otherwise
    // default. In any case in the envelope type it should be event. Except for transactions
    NSString *envelopeType = [event.type isEqualToString:SentryEnvelopeItemTypeTransaction]
        ? SentryEnvelopeItemTypeTransaction
        : SentryEnvelopeItemTypeEvent;

    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc] initWithType:envelopeType
                                                                        length:json.length]
                           data:json];
}

- (instancetype)initWithSession:(SentrySession *)session
{
    NSData *json = [NSJSONSerialization dataWithJSONObject:[session serialize]
                                                   options:0
                                                     // TODO: handle error
                                                     error:nil];
    return [self
        initWithHeader:[[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeSession
                                                               length:json.length]
                  data:json];
}

- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback
{

    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:[userFeedback serialize]
                                                   options:0
                                                     error:&error];

    if (nil != error) {
        [SentryLog logWithMessage:@"Couldn't serialize user feedback." andLevel:kSentryLevelError];
        json = [NSData new];
    }

    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc]
                                    initWithType:SentryEnvelopeItemTypeUserFeedback
                                          length:json.length]
                           data:json];
}

- (_Nullable instancetype)initWithAttachment:(SentryAttachment *)attachment
                           maxAttachmentSize:(NSUInteger)maxAttachmentSize
{
    NSData *data = nil;
    if (nil != attachment.data) {
        if (attachment.data.length > maxAttachmentSize) {
            NSString *message =
                [NSString stringWithFormat:@"Dropping attachment with filename '%@', because the "
                                           @"size of the passed data with %lu bytes is bigger than "
                                           @"the maximum allowed attachment size of %lu bytes.",
                          attachment.filename, (unsigned long)attachment.data.length,
                          (unsigned long)maxAttachmentSize];
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];

            return nil;
        }

        data = attachment.data;
    } else if (nil != attachment.path) {

        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary<NSFileAttributeKey, id> *attr =
            [fileManager attributesOfItemAtPath:attachment.path error:&error];

        if (nil != error) {
            NSString *message = [NSString
                stringWithFormat:@"Couldn't check file size of attachment with path: %@. Error: %@",
                attachment.path, error.localizedDescription];
            [SentryLog logWithMessage:message andLevel:kSentryLevelError];

            return nil;
        }

        unsigned long long fileSize = [attr fileSize];

        if (fileSize > maxAttachmentSize) {
            NSString *message = [NSString
                stringWithFormat:
                    @"Dropping attachment, because the size of the it located at '%@' with %llu "
                    @"bytes is bigger than the maximum allowed attachment size of %lu bytes.",
                attachment.path, fileSize, (unsigned long)maxAttachmentSize];
            [SentryLog logWithMessage:message andLevel:kSentryLevelDebug];
            return nil;
        }

        data = [[NSFileManager defaultManager] contentsAtPath:attachment.path];
    }

    if (nil == data) {
        [SentryLog logWithMessage:@"Couldn't init Attachment." andLevel:kSentryLevelError];
        return nil;
    }

    SentryEnvelopeItemHeader *itemHeader =
        [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeAttachment
                                                length:data.length
                                             filenname:attachment.filename
                                           contentType:attachment.contentType];

    return [self initWithHeader:itemHeader data:data];
}

@end

@implementation SentryEnvelope

- (instancetype)initWithSession:(SentrySession *)session
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithSession:session];
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] singleItem:item];
}

- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions
{
    NSMutableArray *envelopeItems = [[NSMutableArray alloc] initWithCapacity:sessions.count];
    for (int i = 0; i < sessions.count; ++i) {
        SentryEnvelopeItem *item =
            [[SentryEnvelopeItem alloc] initWithSession:[sessions objectAtIndex:i]];
        [envelopeItems addObject:item];
    }
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] items:envelopeItems];
}

- (instancetype)initWithEvent:(SentryEvent *)event
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithEvent:event];
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:event.eventId]
                     singleItem:item];
}

- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithUserFeedback:userFeedback];

    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:userFeedback.eventId]
                     singleItem:item];
}

- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item
{
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] singleItem:item];
}

- (instancetype)initWithId:(SentryId *_Nullable)id items:(NSArray<SentryEnvelopeItem *> *)items
{
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] items:items];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item
{
    return [self initWithHeader:header items:@[ item ]];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items
{
    if (self = [super init]) {
        _header = header;
        _items = items;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
