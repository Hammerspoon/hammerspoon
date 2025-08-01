#import "SentryNSURLRequestBuilder.h"
#import "SentryDsn.h"
#import "SentryLogC.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryNSURLRequestBuilder

- (nullable NSURLRequest *)createEnvelopeRequest:(SentryEnvelope *)envelope
                                             dsn:(SentryDsn *)dsn
                                didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSData *data = [SentrySerialization dataWithEnvelope:envelope];
    if (nil == data) {
        SENTRY_LOG_ERROR(@"Envelope cannot be converted to data");
        return nil;
    }
    return [SentryURLRequestFactory envelopeRequestWith:dsn data:data error:error];
}

- (nullable NSURLRequest *)createEnvelopeRequest:(SentryEnvelope *)envelope
                                             url:(NSURL *)url
                                didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSData *data = [SentrySerialization dataWithEnvelope:envelope];
    if (nil == data) {
        SENTRY_LOG_ERROR(@"Envelope cannot be converted to data");
        return nil;
    }
    return [SentryURLRequestFactory envelopeRequestWith:url data:data authHeader:nil error:error];
}

@end

NS_ASSUME_NONNULL_END
