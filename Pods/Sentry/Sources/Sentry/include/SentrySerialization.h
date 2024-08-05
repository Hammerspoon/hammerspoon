#import "SentryDefines.h"

@class SentrySession, SentryEnvelope, SentryAppState, SentryReplayRecording;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(id)jsonObject;

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session;

+ (SentrySession *_Nullable)sessionWithData:(NSData *)sessionData;

+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
                                error:(NSError *_Nullable *_Nullable)error;

+ (NSData *)dataWithReplayRecording:(SentryReplayRecording *)replayRecording;

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
