#import "SentrySerialization.h"
#import "SentryAppState.h"
#import "SentryDateUtils.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryError.h"
#import "SentryLevelMapper.h"
#import "SentryLogC.h"
#import "SentrySdkInfo.h"
#import "SentrySession.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySerialization

+ (NSData *_Nullable)dataWithJSONObject:(id)jsonObject
{
    if (![NSJSONSerialization isValidJSONObject:jsonObject]) {
        SENTRY_LOG_ERROR(@"Dictionary is not a valid JSON object.");
        return nil;
    }

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:&error];
    if (error) {
        SENTRY_LOG_ERROR(@"Internal error while serializing JSON: %@", error);
    }

    return data;
}

+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
{
    NSMutableData *envelopeData = [[NSMutableData alloc] init];
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    if (nil != envelope.header.eventId) {
        [serializedData setValue:[envelope.header.eventId sentryIdString] forKey:@"event_id"];
    }

    SentrySdkInfo *sdkInfo = envelope.header.sdkInfo;
    if (nil != sdkInfo) {
        [serializedData setValue:[sdkInfo serialize] forKey:@"sdk"];
    }

    SentryTraceContext *traceContext = envelope.header.traceContext;
    if (traceContext != nil) {
        [serializedData setValue:[traceContext serialize] forKey:@"trace"];
    }

    NSDate *sentAt = envelope.header.sentAt;
    if (sentAt != nil) {
        [serializedData setValue:sentry_toIso8601String(sentAt) forKey:@"sent_at"];
    }
    NSData *header = [SentrySerialization dataWithJSONObject:serializedData];
    if (nil == header) {
        SENTRY_LOG_ERROR(@"Envelope header cannot be converted to JSON.");
        return nil;
    }
    [envelopeData appendData:header];

    for (int i = 0; i < envelope.items.count; ++i) {
        [envelopeData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSDictionary *serializedItemHeaderData = [envelope.items[i].header serialize];

        NSData *itemHeader = [SentrySerialization dataWithJSONObject:serializedItemHeaderData];
        if (nil == itemHeader) {
            SENTRY_LOG_ERROR(@"Envelope item header cannot be converted to JSON.");
            return nil;
        }
        [envelopeData appendData:itemHeader];
        [envelopeData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [envelopeData appendData:envelope.items[i].data];
    }

    return envelopeData;
}

+ (SentryEnvelope *_Nullable)envelopeWithData:(NSData *)data
{
    SentryEnvelopeHeader *envelopeHeader = nil;
    const unsigned char *bytes = [data bytes];
    NSUInteger envelopeHeaderIndex = 0;

    for (NSUInteger i = 0; i < data.length; ++i) {
        if (bytes[i] == '\n') {
            envelopeHeaderIndex = i;
            // Envelope header end
            NSData *headerData = [NSData dataWithBytes:bytes length:i];
#ifdef DEBUG
            NSString *headerString = [[NSString alloc] initWithData:headerData
                                                           encoding:NSUTF8StringEncoding];
            SENTRY_LOG_DEBUG(@"Header %@", headerString);
#endif
            NSError *error = nil;
            NSDictionary *headerDictionary = [NSJSONSerialization JSONObjectWithData:headerData
                                                                             options:0
                                                                               error:&error];
            if (nil != error) {
                SENTRY_LOG_ERROR(@"Failed to parse envelope header %@", error);
                break;
            }

            SentryId *eventId = nil;
            NSString *eventIdAsString = headerDictionary[@"event_id"];
            if (nil != eventIdAsString) {
                eventId = [[SentryId alloc] initWithUUIDString:eventIdAsString];
            }

            SentrySdkInfo *sdkInfo = nil;
            if (nil != headerDictionary[@"sdk"]) {
                sdkInfo = [[SentrySdkInfo alloc] initWithDict:headerDictionary[@"sdk"]];
            }

            SentryTraceContext *traceContext = nil;
            if (nil != headerDictionary[@"trace"]) {
                traceContext = [[SentryTraceContext alloc] initWithDict:headerDictionary[@"trace"]];
            }

            envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:eventId
                                                              sdkInfo:sdkInfo
                                                         traceContext:traceContext];

            if (headerDictionary[@"sent_at"] != nil) {
                envelopeHeader.sentAt = sentry_fromIso8601String(headerDictionary[@"sent_at"]);
            }

            break;
        }
    }

    if (nil == envelopeHeader) {
        SENTRY_LOG_ERROR(@"Invalid envelope. No header found.");
        return nil;
    }

    if (envelopeHeaderIndex == 0) {
        SENTRY_LOG_ERROR(@"EnvelopeHeader was parsed, its index is expected.");
        return nil;
    }

    // Parse items
    NSUInteger itemHeaderStart = envelopeHeaderIndex + 1;

    NSMutableArray<SentryEnvelopeItem *> *items = [NSMutableArray new];
    NSUInteger endOfEnvelope = data.length - 1;

    for (NSUInteger i = itemHeaderStart; i <= endOfEnvelope; ++i) {
        if (bytes[i] == '\n' || i == endOfEnvelope) {

            NSData *itemHeaderData =
                [data subdataWithRange:NSMakeRange(itemHeaderStart, i - itemHeaderStart)];
#ifdef DEBUG
            NSString *itemHeaderString = [[NSString alloc] initWithData:itemHeaderData
                                                               encoding:NSUTF8StringEncoding];
            SENTRY_LOG_DEBUG(@"Item Header %@", itemHeaderString);
#endif
            NSError *error = nil;
            NSDictionary *headerDictionary = [NSJSONSerialization JSONObjectWithData:itemHeaderData
                                                                             options:0
                                                                               error:&error];
            if (nil != error) {
                SENTRY_LOG_ERROR(@"Failed to parse envelope item header %@", error);
                return nil;
            }
            NSString *_Nullable type = [headerDictionary valueForKey:@"type"];
            if (nil == type) {
                SENTRY_LOG_ERROR(@"Envelope item type is required.");
                break;
            }
            NSNumber *bodyLengthNumber = [headerDictionary valueForKey:@"length"];
            NSUInteger bodyLength = [bodyLengthNumber unsignedIntegerValue];
            if (endOfEnvelope == i && bodyLength != 0) {
                SENTRY_LOG_ERROR(
                    @"Envelope item has no data but header indicates it's length is %d.",
                    (int)bodyLength);
                break;
            }

            NSString *filename = [headerDictionary valueForKey:@"filename"];
            NSString *contentType = [headerDictionary valueForKey:@"content_type"];
            NSString *attachmentType = [headerDictionary valueForKey:@"attachment_type"];
            NSNumber *itemCount = [headerDictionary valueForKey:@"item_count"];

            SentryEnvelopeItemHeader *itemHeader;
            if (nil != filename) {
                itemHeader = [[SentryEnvelopeAttachmentHeader alloc]
                      initWithType:type
                            length:bodyLength
                          filename:filename
                       contentType:contentType
                    attachmentType:typeForSentryAttachmentName(attachmentType)];
            } else if (nil != itemCount) {
                itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:type
                                                                     length:bodyLength
                                                                contentType:contentType
                                                                  itemCount:itemCount];
            } else {
                itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:type length:bodyLength];
            }

            if (endOfEnvelope == i) {
                i++; // 0 byte attachment
            }

            if (bodyLength > 0 && data.length < (i + 1 + bodyLength)) {
                SENTRY_LOG_ERROR(@"Envelope is corrupted or has invalid data. Trying to read %li "
                                 @"bytes by skipping %li from a buffer of %li bytes.",
                    (unsigned long)data.length, (unsigned long)bodyLength, (long)(i + 1));
                return nil;
            }

            NSData *itemBody = [data subdataWithRange:NSMakeRange(i + 1, bodyLength)];
            SentryEnvelopeItem *envelopeItem = [[SentryEnvelopeItem alloc] initWithHeader:itemHeader
                                                                                     data:itemBody];
            [items addObject:envelopeItem];
            i = itemHeaderStart = i + 1 + [bodyLengthNumber integerValue];
        }
    }

    if (items.count == 0) {
        SENTRY_LOG_ERROR(@"Envelope has no items.");
        return nil;
    }

    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader items:items];
    return envelope;
}

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session
{
    return [self dataWithJSONObject:[session serialize]];
}

+ (SentrySession *_Nullable)sessionWithData:(NSData *)sessionData
{
    NSError *error = nil;
    NSDictionary *sessionDictionary = [NSJSONSerialization JSONObjectWithData:sessionData
                                                                      options:0
                                                                        error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to deserialize session data %@", error);
        return nil;
    }
    SentrySession *session = [[SentrySession alloc] initWithJSONObject:sessionDictionary];

    if (nil == session) {
        SENTRY_LOG_ERROR(@"Failed to initialize session from dictionary. Dropping it.");
        return nil;
    }

    if (nil == session.releaseName || [session.releaseName isEqualToString:@""]) {
        SENTRY_LOG_ERROR(@"Deserialized session doesn't contain a release name. Dropping it.");
        return nil;
    }

    return session;
}

+ (NSData *)dataWithReplayRecording:(SentryReplayRecording *)replayRecording
{
    NSMutableData *recording = [NSMutableData data];
    [recording appendData:[SentrySerialization
                              dataWithJSONObject:[replayRecording headerForReplayRecording]]];
    [recording appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [recording appendData:[SentrySerialization dataWithJSONObject:[replayRecording serialize]]];
    return recording;
}

+ (SentryAppState *_Nullable)appStateWithData:(NSData *)data
{
    NSError *error = nil;
    NSDictionary *appSateDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to deserialize app state data %@", error);
        return nil;
    }

    return [[SentryAppState alloc] initWithJSONObject:appSateDictionary];
}

+ (NSDictionary *_Nullable)deserializeDictionaryFromJsonData:(NSData *)data
{
    NSError *error = nil;
    NSDictionary *_Nullable eventDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:0
                                                                                error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to deserialize json item dictionary: %@", error);
    }

    return eventDictionary;
}

+ (SentryLevel)levelFromData:(NSData *)eventEnvelopeItemData
{
    NSError *error = nil;
    NSDictionary *eventDictionary = [NSJSONSerialization JSONObjectWithData:eventEnvelopeItemData
                                                                    options:0
                                                                      error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to retrieve event level from envelope item data: %@", error);
        return kSentryLevelError;
    }

    return sentryLevelForString(eventDictionary[@"level"]);
}

+ (NSArray *_Nullable)deserializeArrayFromJsonData:(NSData *)data
{
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (nil != error) {
        SENTRY_LOG_ERROR(@"Failed to deserialize json item array: %@", error);
        return nil;
    }
    if (![json isKindOfClass:[NSArray class]]) {
        SENTRY_LOG_ERROR(
            @"Deserialized json is not an NSArray, found %@", NSStringFromClass([json class]));
        return nil;
    }
    return (NSArray *)json;
}

@end

NS_ASSUME_NONNULL_END
