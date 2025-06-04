#import "SentryNSURLRequestBuilder.h"
#import "SentryDsn.h"
#import "SentryLog.h"
#import "SentryNSURLRequest.h"
#import "SentrySerialization.h"

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
    return [[SentryNSURLRequest alloc] initEnvelopeRequestWithDsn:dsn
                                                          andData:data
                                                 didFailWithError:error];
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
    return [[SentryNSURLRequest alloc] initEnvelopeRequestWithURL:url
                                                          andData:data
                                                       authHeader:nil
                                                 didFailWithError:error];
}

@end

NS_ASSUME_NONNULL_END
