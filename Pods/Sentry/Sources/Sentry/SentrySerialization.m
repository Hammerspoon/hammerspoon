#import "SentrySerialization.h"
#import "SentryAppState.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryError.h"
#import "SentryId.h"
#import "SentryLevelMapper.h"
#import "SentryLog.h"
#import "SentrySdkInfo.h"
#import "SentrySession.h"
#import "SentryTraceContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySerialization

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary
                                  error:(NSError *_Nullable *_Nullable)error
{
// We'll do this whether we're handling an exception or library error
#define SENTRY_HANDLE_ERROR(__sentry_error)                                                        \
    SENTRY_LOG_ERROR(@"Invalid JSON: %@", __sentry_error);                                         \
    *error = __sentry_error;                                                                       \
    return nil;

    NSData *data = nil;

#if defined(DEBUG) || defined(TEST) || defined(TESTCI)
    @try {
#else
    if ([NSJSONSerialization isValidJSONObject:dictionary]) {
#endif
        data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:error];
#if defined(DEBUG) || defined(TEST) || defined(TESTCI)
    } @catch (NSException *exception) {
        if (error) {
            SENTRY_HANDLE_ERROR(NSErrorFromSentryErrorWithException(
                kSentryErrorJsonConversionError, @"Event cannot be converted to JSON", exception));
        }
    }
#else
    } else if (error) {
        SENTRY_HANDLE_ERROR(NSErrorFromSentryErrorWithUnderlyingError(
            kSentryErrorJsonConversionError, @"Event cannot be converted to JSON", *error));
    }
#endif

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

    NSData *header = [SentrySerialization dataWithJSONObject:serializedData error:error];
    if (nil == header) {
        SENTRY_LOG_ERROR(@"Envelope header cannot be converted to JSON.");
        if (error) {
            *error = NSErrorFromSentryError(
                kSentryErrorJsonConversionError, @"Envelope header cannot be converted to JSON");
        }
        return nil;
    }
    [envelopeData appendData:header];

    for (int i = 0; i < envelope.items.count; ++i) {
        [envelopeData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSDictionary *serializedItemHeaderData = [envelope.items[i].header serialize];

        NSData *itemHeader = [SentrySerialization dataWithJSONObject:serializedItemHeaderData
                                                               error:error];
        if (nil == itemHeader) {
            SENTRY_LOG_ERROR(@"Envelope item header cannot be converted to JSON.");
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

+ (NSString *)baggageEncodedDictionary:(NSDictionary *)dictionary
{
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:dictionary.count];

    NSMutableCharacterSet *allowedSet = [NSCharacterSet.alphanumericCharacterSet mutableCopy];
    [allowedSet addCharactersInString:@"-_."];
    NSInteger currentSize = 0;

    for (id key in dictionary.allKeys) {
        id value = dictionary[key];
        NSString *keyDescription =
            [[key description] stringByAddingPercentEncodingWithAllowedCharacters:allowedSet];
        NSString *valueDescription =
            [[value description] stringByAddingPercentEncodingWithAllowedCharacters:allowedSet];

        NSString *item = [NSString stringWithFormat:@"%@=%@", keyDescription, valueDescription];
        if (item.length + currentSize <= SENTRY_BAGGAGE_MAX_SIZE) {
            currentSize += item.length
                + 1; // +1 is to account for the comma that will be added for each extra itemapp
            [items addObject:item];
        }
    }

    return [[items sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj1 compare:obj2];
    }] componentsJoinedByString:@","];
}

+ (NSDictionary<NSString *, NSString *> *)decodeBaggage:(NSString *)baggage
{
    if (baggage == nil || baggage.length == 0) {
        return @{};
    }

    NSMutableDictionary *decoded = [[NSMutableDictionary alloc] init];

    NSArray<NSString *> *properties = [baggage componentsSeparatedByString:@","];

    for (NSString *property in properties) {
        NSArray<NSString *> *parts = [property componentsSeparatedByString:@"="];
        if (parts.count != 2) {
            continue;
        }
        NSString *key = parts[0];
        NSString *value = [parts[1] stringByRemovingPercentEncoding];
        decoded[key] = value;
    }

    return decoded.copy;
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

    return sentryLevelForString(eventDictionary[@"level"]);
}

@end

NS_ASSUME_NONNULL_END
