#import "SentryDefines.h"

@class SentryEnvelope;
@class SentrySession;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySerialization : NSObject

/**
 * Retrieves the json object from an event envelope item data.
 */
+ (NSDictionary *_Nullable)deserializeDictionaryFromJsonData:(NSData *)data;

/**
 * Extract the level from data of an envelopte item containing an event. Default is the 'error'
 * level, see https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
 */
+ (SentryLevel)levelFromData:(NSData *)eventEnvelopeItemData;

/**
 * Retrieves the json object from an event envelope item data.
 */
+ (NSArray *_Nullable)deserializeArrayFromJsonData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
