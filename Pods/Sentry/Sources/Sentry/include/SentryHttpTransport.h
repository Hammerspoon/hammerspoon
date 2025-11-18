#import "SentryDefines.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryRateLimits.h"
#import "SentryRequestManager.h"
#import "SentryTransport.h"

@class SentryFileManager;
@class SentryDispatchQueueWrapper;
@class SentryNSURLRequestBuilder;
@class SentryDsn;
@protocol SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHttpTransport : NSObject <SentryTransport, SentryEnvelopeRateLimitDelegate>
SENTRY_NO_INIT

- (id)initWithDsn:(SentryDsn *)dsn
          sendClientReports:(BOOL)sendClientReports
    cachedEnvelopeSendDelay:(NSTimeInterval)cachedEnvelopeSendDelay
               dateProvider:(id<SentryCurrentDateProvider>)dateProvider
                fileManager:(SentryFileManager *)fileManager
             requestManager:(id<SentryRequestManager>)requestManager
             requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
                 rateLimits:(id<SentryRateLimits>)rateLimits
          envelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
       dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

@end

NS_ASSUME_NONNULL_END
