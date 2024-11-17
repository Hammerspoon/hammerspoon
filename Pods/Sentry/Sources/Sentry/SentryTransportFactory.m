#import "SentryTransportFactory.h"
#import "SentryDefaultRateLimits.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryHttpDateParser.h"
#import "SentryHttpTransport.h"
#import "SentryNSURLRequestBuilder.h"
#import "SentryOptions.h"
#import "SentryQueueableRequestManager.h"
#import "SentryRateLimitParser.h"
#import "SentryRateLimits.h"

#import "SentryRetryAfterHeaderParser.h"
#import "SentrySpotlightTransport.h"
#import "SentryTransport.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransportFactory ()

@end

@implementation SentryTransportFactory

+ (NSArray<id<SentryTransport>> *)initTransports:(SentryOptions *)options
                               sentryFileManager:(SentryFileManager *)sentryFileManager
                             currentDateProvider:(SentryCurrentDateProvider *)currentDateProvider
{
    NSURLSession *session;

    if (options.urlSession) {
        session = options.urlSession;
    } else {
        NSURLSessionConfiguration *configuration =
            [NSURLSessionConfiguration ephemeralSessionConfiguration];
        session = [NSURLSession sessionWithConfiguration:configuration
                                                delegate:options.urlSessionDelegate
                                           delegateQueue:nil];
    }

    id<SentryRequestManager> requestManager =
        [[SentryQueueableRequestManager alloc] initWithSession:session];

    SentryHttpDateParser *httpDateParser = [[SentryHttpDateParser alloc] init];
    SentryRetryAfterHeaderParser *retryAfterHeaderParser =
        [[SentryRetryAfterHeaderParser alloc] initWithHttpDateParser:httpDateParser
                                                 currentDateProvider:currentDateProvider];
    SentryRateLimitParser *rateLimitParser =
        [[SentryRateLimitParser alloc] initWithCurrentDateProvider:currentDateProvider];
    id<SentryRateLimits> rateLimits =
        [[SentryDefaultRateLimits alloc] initWithRetryAfterHeaderParser:retryAfterHeaderParser
                                                     andRateLimitParser:rateLimitParser
                                                    currentDateProvider:currentDateProvider];

    SentryEnvelopeRateLimit *envelopeRateLimit =
        [[SentryEnvelopeRateLimit alloc] initWithRateLimits:rateLimits];

    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_LOW, 0);
    SentryDispatchQueueWrapper *dispatchQueueWrapper =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-http-transport"
                                              attributes:attributes];

    SentryNSURLRequestBuilder *requestBuilder = [[SentryNSURLRequestBuilder alloc] init];

    SentryHttpTransport *httpTransport =
        [[SentryHttpTransport alloc] initWithOptions:options
                             cachedEnvelopeSendDelay:0.1
                                         fileManager:sentryFileManager
                                      requestManager:requestManager
                                      requestBuilder:requestBuilder
                                          rateLimits:rateLimits
                                   envelopeRateLimit:envelopeRateLimit
                                dispatchQueueWrapper:dispatchQueueWrapper];

    if (options.enableSpotlight) {
        SentrySpotlightTransport *spotlightTransport =
            [[SentrySpotlightTransport alloc] initWithOptions:options
                                               requestManager:requestManager
                                               requestBuilder:requestBuilder
                                         dispatchQueueWrapper:dispatchQueueWrapper];
        return @[ httpTransport, spotlightTransport ];
    } else {
        return @[ httpTransport ];
    }
}

@end

NS_ASSUME_NONNULL_END
