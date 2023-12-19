#import "SentryDefines.h"

@class SentrySession, SentryEnvelope, SentryAppState;

NS_ASSUME_NONNULL_BEGIN

static int const SENTRY_BAGGAGE_MAX_SIZE = 8192;

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary;

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session;

+ (NSDictionary<NSString *, NSString *> *)decodeBaggage:(NSString *)baggage;
+ (NSString *)baggageEncodedDictionary:(NSDictionary *)dictionary;

+ (SentrySession *_Nullable)sessionWithData:(NSData *)sessionData;

+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
                                error:(NSError *_Nullable *_Nullable)error;

+ (SentryEnvelope *_Nullable)envelopeWithData:(NSData *)data;

+ (SentryAppState *_Nullable)appStateWithData:(NSData *)sessionData;

/**
 * Retrieves the json object from an event envelope item data.
 */
+ (NSDictionary *)deserializeEventEnvelopeItem:(NSData *)eventEnvelopeItemData;

/**
 * Extract the level from data of an envelopte item containing an event. Default is the 'error'
 * level, see https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
 */
+ (SentryLevel)levelFromData:(NSData *)eventEnvelopeItemData;

@end

NS_ASSUME_NONNULL_END
