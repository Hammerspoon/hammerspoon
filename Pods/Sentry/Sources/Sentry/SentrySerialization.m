#import "SentrySerialization.h"
#import "SentryAppState.h"
#import "SentryDefines.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryError.h"
#import "SentryId.h"
#import "SentryLevelMapper.h"
#import "SentryLog.h"
#import "SentrySdkInfo.h"
#import "SentrySession.h"
#import "SentryTraceState.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySerialization

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary
                                  error:(NSError *_Nullable *_Nullable)error
{
    NSData *data = nil;
    if ([NSJSONSerialization isValidJSONObject:dictionary] != NO) {
        data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:error];
    } else {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Invalid JSON."]
                         andLevel:kSentryLevelError];
        if (error) {
            *error = NSErrorFromSentryError(
                kSentryErrorJsonConversionError, @"Event cannot be converted to JSON");
        }
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

    SentryTraceState *traceState = envelope.header.traceState;
    if (traceState != nil) {
        [serializedData setValue:[traceState serialize] forKey:@"trace"];
    }

    NSData *header = [SentrySerialization dataWithJSONObject:serializedData error:error];
    if (nil == header) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Envelope header cannot "
                                                             @"be converted to JSON."]
                         andLevel:kSentryLevelError];
        if (error) {
            *error = NSErrorFromSentryError(
                kSentryErrorJsonConversionError, @"Envelope header cannot be converted to JSON");
        }
        return nil;
    }
    [envelopeData appendData:header];

    for (int i = 0; i < envelope.items.count; ++i) {
        [envelopeData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSMutableDictionary *serializedItemHeaderData = [NSMutableDictionary new];
        if (nil != envelope.items[i].header) {
            if (nil != envelope.items[i].header.type) {
                [serializedItemHeaderData setValue:envelope.items[i].header.type forKey:@"type"];
            }

            NSString *filename = envelope.items[i].header.filename;
            if (nil != filename) {
                [serializedItemHeaderData setValue:filename forKey:@"filename"];
            }

            NSString *contentType = envelope.items[i].header.contentType;
            if (nil != contentType) {
                [serializedItemHeaderData setValue:contentType forKey:@"content_type"];
            }

            [serializedItemHeaderData
                setValue:[NSNumber numberWithUnsignedInteger:envelope.items[i].header.length]
                  forKey:@"length"];
        }
        NSData *itemHeader = [SentrySerialization dataWithJSONObject:serializedItemHeaderData
                                                               error:error];
        if (nil == itemHeader) {
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Envelope item header cannot "
                                                                 @"be converted to JSON."]
                             andLevel:kSentryLevelError];
            if (error) {
                *error = NSErrorFromSentryError(kSentryErrorJsonConversionError,
                    @"Envelope item header cannot be converted to JSON");
            }
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
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Header %@", headerString]
                             andLevel:kSentryLevelDebug];
#endif
            NSError *error = nil;
            NSDictionary *headerDictionary = [NSJSONSerialization JSONObjectWithData:headerData
                                                                             options:0
                                                                               error:&error];
            if (nil != error) {
                [SentryLog logWithMessage:[NSString stringWithFormat:@"Failed to parse "
                                                                     @"envelope header %@",
                                                    error]
                                 andLevel:kSentryLevelError];
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

                SentryTraceState *traceState = nil;
                if (nil != headerDictionary[@"trace"]) {
                    traceState = [[SentryTraceState alloc] initWithDict:headerDictionary[@"trace"]];
                }

                envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:eventId
                                                                  sdkInfo:sdkInfo
                                                               traceState:traceState];
            }
            break;
        }
    }
    if (nil == envelopeHeader) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Invalid envelope. No header found."]
                         andLevel:kSentryLevelError];
        return nil;
    }
    NSAssert(envelopeHeaderIndex > 0, @"EnvelopeHeader was parsed, its index is expected.");
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

            NSString *_Nullable filename = [headerDictionary valueForKey:@"filename"];
            NSString *_Nullable contentType = [headerDictionary valueForKey:@"content_type"];

            SentryEnvelopeItemHeader *itemHeader;
            if (nil != filename && nil != contentType) {
                itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:type
                                                                     length:bodyLength
                                                                  filenname:filename
                                                                contentType:contentType];
            } else {
                itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:type length:bodyLength];
            }

            NSData *itemBody = [data subdataWithRange:NSMakeRange(i + 1, bodyLength)];
#ifdef DEBUG
            if ([SentryEnvelopeItemTypeEvent isEqual:type] ||
                [SentryEnvelopeItemTypeSession isEqual:type]) {
                NSString *event = [[NSString alloc] initWithData:itemBody
                                                        encoding:NSUTF8StringEncoding];
                [SentryLog logWithMessage:[NSString stringWithFormat:@"Event %@", event]
                                 andLevel:kSentryLevelDebug];
            }
#endif
            SentryEnvelopeItem *envelopeItem = [[SentryEnvelopeItem alloc] initWithHeader:itemHeader
                                                                                     data:itemBody];
            [items addObject:envelopeItem];
            i = itemHeaderStart = i + 1 + [bodyLengthNumber integerValue];
        }
    }

    if (items.count == 0) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Envelope has no items."]
                         andLevel:kSentryLevelError];
        return nil;
    }

    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader items:items];
    return envelope;
}

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session
                               error:(NSError *_Nullable *_Nullable)error
{
    return [self dataWithJSONObject:[session serialize] error:error];
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
        [SentryLog logWithMessage:@"Failed to initialize session from dictionary. Dropping it."
                         andLevel:kSentryLevelError];
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

    return [SentryLevelMapper levelWithString:eventDictionary[@"level"]];
}

@end

NS_ASSUME_NONNULL_END
