#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryEnvelope.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentrySerialization : NSObject

+ (NSData *_Nullable)dataWithJSONObject:(NSDictionary *)dictionary
                                options:(NSJSONWritingOptions)opt
                                  error:(NSError *_Nullable *_Nullable)error;

+ (NSData *_Nullable)dataWithSession:(SentrySession *)session
                             options:(NSJSONWritingOptions)opt
                               error:(NSError *_Nullable *_Nullable)error;

+ (SentrySession *_Nullable) sessionWithData:(NSData *)sessionData;

// TODO: use (NSOutputStream *)outputStream
+ (NSData *_Nullable)dataWithEnvelope:(SentryEnvelope *)envelope
                              options:(NSJSONWritingOptions)opt
                                error:(NSError *_Nullable *_Nullable)error;

// TODO: (NSInputStream *)inputStream
+ (SentryEnvelope *_Nullable) envelopeWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
