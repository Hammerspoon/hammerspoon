#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentrySession, SentryEnvelope, SentryAppState;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary
                                  error:(NSError *_Nullable *_Nullable)error;

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session
                               error:(NSError *_Nullable *_Nullable)error;

+ (SentrySession *_Nullable)sessionWithData:(NSData *)sessionData;

// TODO: use (NSOutputStream *)outputStream
+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
                                error:(NSError *_Nullable *_Nullable)error;

// TODO: (NSInputStream *)inputStream
+ (SentryEnvelope *_Nullable)envelopeWithData:(NSData *)data;

+ (SentryAppState *_Nullable)appStateWithData:(NSData *)sessionData;

/**
 * Extract the level from data of an envelopte item containing an event. Default is the 'error'
 * level, see https://develop.sentry.dev/sdk/event-payloads/#optional-attributes
 */
+ (SentryLevel)levelFromData:(NSData *)eventEnvelopeItemData;

@end

NS_ASSUME_NONNULL_END
