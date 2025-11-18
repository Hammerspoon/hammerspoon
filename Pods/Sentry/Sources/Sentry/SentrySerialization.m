#import "SentrySerialization.h"
#import "SentryDateUtils.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryError.h"
#import "SentryInternalDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLogC.h"
#import "SentryModels+Serializable.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySerialization

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
