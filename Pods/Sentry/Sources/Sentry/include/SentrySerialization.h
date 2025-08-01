#import "SentryDefines.h"

@class SentryAppState;
@class SentryEnvelope;
@class SentryReplayRecording;
@class SentrySession;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(id)jsonObject;

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session;

+ (SentrySession *_Nullable)sessionWithData:(NSData *)sessionData;

+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope;

+ (NSData *)dataWithReplayRecording:(SentryReplayRecording *)replayRecording;

+ (SentryEnvelope *_Nullable)envelopeWithData:(NSData *)data;

+ (SentryAppState *_Nullable)appStateWithData:(NSData *)sessionData;

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
