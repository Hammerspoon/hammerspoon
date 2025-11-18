#import "SentryTransportFactory.h"
#import "SentryDefaultRateLimits.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryHttpDateParser.h"
#import "SentryHttpTransport.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryNSURLRequestBuilder.h"
#import "SentryOptions.h"
#import "SentryQueueableRequestManager.h"
#import "SentryRateLimitParser.h"
#import "SentryRateLimits.h"
#import "SentrySwift.h"

#import "SentryRetryAfterHeaderParser.h"
#import "SentrySpotlightTransport.h"
#import "SentryTransport.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryTransportFactory ()

@end

@implementation SentryTransportFactory

+ (NSArray<id<SentryTransport>> *)initTransports:(SentryOptions *)options
                                    dateProvider:(id<SentryCurrentDateProvider>)dateProvider
                               sentryFileManager:(SentryFileManager *)sentryFileManager
                                      rateLimits:(id<SentryRateLimits>)rateLimits
{
    NSMutableArray<id<SentryTransport>> *transports = [NSMutableArray array];

    NSURLSession *session = [self getUrlSession:options];
    id<SentryRequestManager> requestManager =
        [[SentryQueueableRequestManager alloc] initWithSession:session];
    SentryEnvelopeRateLimit *envelopeRateLimit =
        [[SentryEnvelopeRateLimit alloc] initWithRateLimits:rateLimits];
    SentryDispatchQueueWrapper *dispatchQueueWrapper = [self createDispatchQueueWrapper];

    SentryNSURLRequestBuilder *requestBuilder = [[SentryNSURLRequestBuilder alloc] init];

    if (options.enableSpotlight) {
        SENTRY_LOG_DEBUG(@"Spotlight is enabled, creating Spotlight transport.");
        SentrySpotlightTransport *spotlightTransport =
            [[SentrySpotlightTransport alloc] initWithOptions:options
                                               requestManager:requestManager
                                               requestBuilder:requestBuilder
                                         dispatchQueueWrapper:dispatchQueueWrapper];

        [transports addObject:spotlightTransport];
    } else {
        SENTRY_LOG_DEBUG(@"Spotlight is disabled in options, not adding Spotlight transport.");
    }

    if (options.parsedDsn) {
        SENTRY_LOG_DEBUG(@"Options contain parsed DSN, creating HTTP transport.");
        SentryDsn *_Nonnull dsn = SENTRY_UNWRAP_NULLABLE(SentryDsn, options.parsedDsn);

        SentryHttpTransport *httpTransport =
            [[SentryHttpTransport alloc] initWithDsn:dsn
                                   sendClientReports:options.sendClientReports
                             cachedEnvelopeSendDelay:0.1
                                        dateProvider:dateProvider
                                         fileManager:sentryFileManager
                                      requestManager:requestManager
                                      requestBuilder:requestBuilder
                                          rateLimits:rateLimits
                                   envelopeRateLimit:envelopeRateLimit
                                dispatchQueueWrapper:dispatchQueueWrapper];

        [transports addObject:httpTransport];
    } else {
        SENTRY_LOG_WARN(
            @"Failed to create HTTP transport because the SentryOptions does not contain "
            @"a parsed DSN.");
    }

    return transports;
}

+ (NSURLSession *)getUrlSession:(SentryOptions *_Nonnull)options
{
    if (options.urlSession) {
        SENTRY_LOG_DEBUG(@"Using URL session provided in SDK options for HTTP transport.");
        return SENTRY_UNWRAP_NULLABLE(NSURLSession, options.urlSession);
    }

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    return [NSURLSession sessionWithConfiguration:configuration
                                         delegate:options.urlSessionDelegate
                                    delegateQueue:nil];
}

+ (SentryDispatchQueueWrapper *)createDispatchQueueWrapper
{
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_LOW, 0);
    SentryDispatchQueueWrapper *dispatchQueueWrapper =
        [[SentryDispatchQueueWrapper alloc] initWithName:"io.sentry.http-transport"
                                              attributes:attributes];
    return dispatchQueueWrapper;
}
@end

NS_ASSUME_NONNULL_END
