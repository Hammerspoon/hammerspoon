#import "SentryAttachment.h"
#import "SentryBreadcrumb.h"
#import "SentryClientReport.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryLog.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentryMsgPackSerializer.h"
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
    self = [self initWithId:eventId traceContext:nil];
    return self;
}

- (instancetype)initWithId:(nullable SentryId *)eventId
              traceContext:(nullable SentryTraceContext *)traceContext
{
    SentrySdkInfo *sdkInfo = [[SentrySdkInfo alloc] initWithName:SentryMeta.sdkName
                                                      andVersion:SentryMeta.versionString];
    self = [self initWithId:eventId sdkInfo:sdkInfo traceContext:traceContext];
    return self;
}

- (instancetype)initWithId:(nullable SentryId *)eventId
                   sdkInfo:(nullable SentrySdkInfo *)sdkInfo
              traceContext:(nullable SentryTraceContext *)traceContext
{
    if (self = [super init]) {
        _eventId = eventId;
        _sdkInfo = sdkInfo;
        _traceContext = traceContext;
    }

    return self;
}

+ (instancetype)empty
{
    return [[SentryEnvelopeHeader alloc] initWithId:nil traceContext:nil];
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
    NSData *json = [SentrySerialization dataWithJSONObject:[event serialize]];

    if (nil == json) {
        // We don't know what caused the serialization to fail.
        SentryEvent *errorEvent = [[SentryEvent alloc] initWithLevel:kSentryLevelWarning];

        // Add some context to the event. We can only set simple properties otherwise we
        // risk that the conversion fails again.
        NSString *message = [NSString
            stringWithFormat:@"JSON conversion error for event with message: '%@'", event.message];

        errorEvent.message = [[SentryMessage alloc] initWithFormatted:message];
        errorEvent.releaseName = event.releaseName;
        errorEvent.environment = event.environment;
        errorEvent.platform = event.platform;
        errorEvent.timestamp = event.timestamp;

        // We accept the risk that this simple serialization fails. Therefore we ignore the
        // error on purpose.
        json = [SentrySerialization dataWithJSONObject:[errorEvent serialize]];
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
    NSData *json = [NSJSONSerialization dataWithJSONObject:[session serialize] options:0 error:nil];
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
        SENTRY_LOG_ERROR(@"Couldn't serialize user feedback.");
        json = [NSData new];
    }

    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc]
                                    initWithType:SentryEnvelopeItemTypeUserFeedback
                                          length:json.length]
                           data:json];
}

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport
{
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:[clientReport serialize]
                                                   options:0
                                                     error:&error];

    if (nil != error) {
        SENTRY_LOG_ERROR(@"Couldn't serialize client report.");
        json = [NSData new];
    }

    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc]
                                    initWithType:SentryEnvelopeItemTypeClientReport
                                          length:json.length]
                           data:json];
}

- (_Nullable instancetype)initWithAttachment:(SentryAttachment *)attachment
                           maxAttachmentSize:(NSUInteger)maxAttachmentSize
{
    NSData *data = nil;
    if (nil != attachment.data) {
        if (attachment.data.length > maxAttachmentSize) {
            SENTRY_LOG_DEBUG(
                @"Dropping attachment with filename '%@', because the size of the passed data with "
                @"%lu bytes is bigger than the maximum allowed attachment size of %lu bytes.",
                attachment.filename, (unsigned long)attachment.data.length,
                (unsigned long)maxAttachmentSize);
            return nil;
        }

        data = attachment.data;
    } else if (nil != attachment.path) {

        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary<NSFileAttributeKey, id> *attr =
            [fileManager attributesOfItemAtPath:attachment.path error:&error];

        if (nil != error) {
            SENTRY_LOG_ERROR(@"Couldn't check file size of attachment with path: %@. Error: %@",
                attachment.path, error.localizedDescription);

            return nil;
        }

        unsigned long long fileSize = [attr fileSize];

        if (fileSize > maxAttachmentSize) {
            SENTRY_LOG_DEBUG(
                @"Dropping attachment, because the size of the it located at '%@' with %llu bytes "
                @"is bigger than the maximum allowed attachment size of %lu bytes.",
                attachment.path, fileSize, (unsigned long)maxAttachmentSize);
            return nil;
        }

        data = [[NSFileManager defaultManager] contentsAtPath:attachment.path];
    }

    if (data == nil) {
        SENTRY_LOG_ERROR(@"Couldn't init Attachment.");
        return nil;
    }

    SentryEnvelopeItemHeader *itemHeader =
        [[SentryEnvelopeAttachmentHeader alloc] initWithType:SentryEnvelopeItemTypeAttachment
                                                      length:data.length
                                                    filename:attachment.filename
                                                 contentType:attachment.contentType
                                              attachmentType:attachment.attachmentType];

    return [self initWithHeader:itemHeader data:data];
}

- (nullable instancetype)initWithReplayEvent:(SentryReplayEvent *)replayEvent
                             replayRecording:(SentryReplayRecording *)replayRecording
                                       video:(NSURL *)videoURL
{
    NSData *replayEventData = [SentrySerialization dataWithJSONObject:[replayEvent serialize]];
    NSData *recording = [SentrySerialization dataWithReplayRecording:replayRecording];
    NSURL *envelopeContentUrl =
        [[videoURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"dat"];

    BOOL success = [SentryMsgPackSerializer serializeDictionaryToMessagePack:@{
        @"replay_event" : replayEventData,
        @"replay_recording" : recording,
        @"replay_video" : videoURL
    }
                                                                    intoFile:envelopeContentUrl];
    if (success == NO) {
        SENTRY_LOG_ERROR(@"Could not create MessagePack for session replay envelope item.");
        return nil;
    }

    NSData *envelopeItemContent = [NSData dataWithContentsOfURL:envelopeContentUrl];

    NSError *error;
    if (![NSFileManager.defaultManager removeItemAtURL:envelopeContentUrl error:&error]) {
        SENTRY_LOG_ERROR(@"Cound not delete temporary replay content from disk: %@", error);
    }
    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc]
                                    initWithType:SentryEnvelopeItemTypeReplayVideo
                                          length:envelopeItemContent.length]
                           data:envelopeItemContent];
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
