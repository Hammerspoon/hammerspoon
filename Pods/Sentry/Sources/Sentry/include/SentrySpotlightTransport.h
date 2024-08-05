#import "SentryDefines.h"
#import "SentryRequestManager.h"
#import "SentryTransport.h"

@class SentryOptions, SentryDispatchQueueWrapper, SentryNSURLRequestBuilder;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySpotlightTransport : NSObject <SentryTransport>
SENTRY_NO_INIT

- (id)initWithOptions:(SentryOptions *)options
          requestManager:(id<SentryRequestManager>)requestManager
          requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

@end

NS_ASSUME_NONNULL_END
