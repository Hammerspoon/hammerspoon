#import "SentrySerialization.h"
#import "SentryAppState.h"
#import "SentryDateUtils.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryError.h"
#import "SentryLevelMapper.h"
#import "SentryLog.h"
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
                                error:(NSError *_Nullable *_Nullable)error
{

    NSMutableData *envelopeData = [[NSMutableData alloc] init];
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    if (nil != envelope.header.eventId) {
        [serializedData setValue:[envelope.header.eventId sentryIdString] forKey:@"event_id"];
    }

    SentrySdkInfo *sdkInfo = envelope.header.sdkInfo;
    if (nil != sdkInfo) {
        [serializedData addEntriesFromDictionary:[sdkInfo serialize]];
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
    int envelopeHeaderIndex = 0;

    for (int i = 0; i < data.length; ++i) {
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
            } else {
                SentryId *eventId = nil;
                NSString *eventIdAsString = headerDictionary[@"event_id"];
                if (nil != eventIdAsString) {
                    eventId = [[SentryId alloc] initWithUUIDString:eventIdAsString];
                }

                SentrySdkInfo *sdkInfo = nil;
                if (nil != headerDictionary[@"sdk"]) {
                    sdkInfo = [[SentrySdkInfo alloc] initWithDict:headerDictionary];
                }

                SentryTraceContext *traceContext = nil;
                if (nil != headerDictionary[@"trace"]) {
                    traceContext =
                        [[SentryTraceContext alloc] initWithDict:headerDictionary[@"trace"]];
                }

                envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:eventId
                                                                  sdkInfo:sdkInfo
                                                             traceContext:traceContext];

                if (headerDictionary[@"sent_at"] != nil) {
                    envelopeHeader.sentAt = sentry_fromIso8601String(headerDictionary[@"sent_at"]);
                }
            }
            break;
        }
    }

    if (nil == envelopeHeader) {
        SENTRY_LOG_ERROR(@"Invalid envelope. No header found.");
        return nil;
    }

    NSAssert(envelopeHeaderIndex > 0, @"EnvelopeHeader was parsed, its index is expected.");
    if (envelopeHeaderIndex == 0) {
        NSLog(@"EnvelopeHeader was parsed, its index is expected.");
        return nil;
    }

    // Parse items
    NSInteger itemHeaderStart = envelopeHeaderIndex + 1;

    NSMutableArray<SentryEnvelopeItem *> *items = [NSMutableArray new];
    NSUInteger endOfEnvelope = data.length - 1;
    for (NSInteger i = itemHeaderStart; i <= endOfEnvelope; ++i) {
        if (bytes[i] == '\n' || i == endOfEnvelope) {
            if (endOfEnvelope == i) {
                i++; // 0 byte attachment
            }

            NSData *itemHeaderData =
                [data subdataWithRange:NSMakeRange(itemHeaderStart, i - itemHeaderStart)];
#ifdef DEBUG
            NSString *itemHeaderString = [[NSString alloc] initWithData:itemHeaderData
                                                               encoding:NSUTF8StringEncoding];
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"Item Header %@", itemHeaderString]
                      andLevel:kSentryLevelDebug];
#endif
            NSError *error = nil;
            NSDictionary *headerDictionary = [NSJSONSerialization JSONObjectWithData:itemHeaderData
                                                                             options:0
                                                                               error:&error];
            if (nil != error) {
                [SentryLog
                    logWithMessage:[NSString
                                       stringWithFormat:@"Failed to parse envelope item header %@",
                                       error]
                          andLevel:kSentryLevelError];
                return nil;
            }
            NSString *_Nullable type = [headerDictionary valueForKey:@"type"];
            if (nil == type) {
                [SentryLog
                    logWithMessage:[NSString stringWithFormat:@"Envelope item type is required."]
                          andLevel:kSentryLevelError];
                break;
            }
            NSNumber *bodyLengthNumber = [headerDictionary valueForKey:@"length"];
            NSUInteger bodyLength = [bodyLengthNumber unsignedIntegerValue];
            if (endOfEnvelope == i && bodyLength != 0) {
                [SentryLog
                    logWithMessage:[NSString
                                       stringWithFormat:@"Envelope item has no data but header "
                                                        @"indicates it's length is %d.",
                                       (int)bodyLength]
                          andLevel:kSentryLevelError];
                break;
            }

            NSString *filename = [headerDictionary valueForKey:@"filename"];
            NSString *contentType = [headerDictionary valueForKey:@"content_type"];
            NSString *attachmentType = [headerDictionary valueForKey:@"attachment_type"];

            SentryEnvelopeItemHeader *itemHeader;
            if (nil != filename) {
                itemHeader = [[SentryEnvelopeAttachmentHeader alloc]
                      initWithType:type
                            length:bodyLength
                          filename:filename
                       contentType:contentType
                    attachmentType:typeForSentryAttachmentName(attachmentType)];
            } else {
                itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:type length:bodyLength];
            }

            NSData *itemBody = [data subdataWithRange:NSMakeRange(i + 1, bodyLength)];
#ifdef DEBUG
            if ([SentryEnvelopeItemTypeEvent isEqual:type] ||
                [SentryEnvelopeItemTypeSession isEqual:type]) {
                NSString *event = [[NSString alloc] initWithData:itemBody
                                                        encoding:NSUTF8StringEncoding];
                SENTRY_LOG_DEBUG(@"Event %@", event);
            }
#endif
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
        [SentryLog
            logWithMessage:[NSString
                               stringWithFormat:@"Failed to deserialize session data %@", error]
                  andLevel:kSentryLevelError];
        return nil;
    }
    SentrySession *session = [[SentrySession alloc] initWithJSONObject:sessionDictionary];

    if (nil == session) {
        SENTRY_LOG_ERROR(@"Failed to initialize session from dictionary. Dropping it.");
        return nil;
    }

    if (nil == session.releaseName || [session.releaseName isEqualToString:@""]) {
        [SentryLog
            logWithMessage:@"Deserialized session doesn't contain a release name. Dropping it."
                  andLevel:kSentryLevelError];
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
        [SentryLog
            logWithMessage:[NSString
                               stringWithFormat:@"Failed to deserialize app state data %@", error]
                  andLevel:kSentryLevelError];
        return nil;
    }

    return [[SentryAppState alloc] initWithJSONObject:appSateDictionary];
}

+ (NSDictionary *)deserializeEventEnvelopeItem:(NSData *)eventEnvelopeItemData
{
    NSError *error = nil;
    NSDictionary *eventDictionary = [NSJSONSerialization JSONObjectWithData:eventEnvelopeItemData
                                                                    options:0
                                                                      error:&error];
    if (nil != error) {
        [SentryLog
            logWithMessage:[NSString
                               stringWithFormat:@"Failed to deserialize envelope item data: %@",
                               error]
                  andLevel:kSentryLevelError];
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
        [SentryLog
            logWithMessage:
                [NSString
                    stringWithFormat:@"Failed to retrieve event level from envelope item data: %@",
                    error]
                  andLevel:kSentryLevelError];
        return kSentryLevelError;
    }

    return sentryLevelForString(eventDictionary[@"level"]);
}

@end

NS_ASSUME_NONNULL_END
