#import "SentrySpotlightTransport.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryLog.h"
#import "SentryNSURLRequest.h"
#import "SentryNSURLRequestBuilder.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"
#import "SentryTransport.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySpotlightTransport ()

@property (nonatomic, strong) id<SentryRequestManager> requestManager;
@property (nonatomic, strong) SentryNSURLRequestBuilder *requestBuilder;
@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong, nullable) NSURL *apiURL;

@end

@implementation SentrySpotlightTransport

- (id)initWithOptions:(SentryOptions *)options
          requestManager:(id<SentryRequestManager>)requestManager
          requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{

    if (self = [super init]) {
        self.options = options;
        self.requestManager = requestManager;
        self.requestBuilder = requestBuilder;
        self.dispatchQueue = dispatchQueueWrapper;
        self.apiURL = [[NSURL alloc] initWithString:options.spotlightUrl];
    }

    return self;
}

- (void)sendEnvelope:(SentryEnvelope *)envelope
{
    if (self.apiURL == nil) {
        SENTRY_LOG_WARN(@"Malformed Spotlight URL passed from the options. Not sending envelope to "
                        @"Spotlight with URL:%@",
            self.options.spotlightUrl);
        return;
    }

    // Spotlight can only handle the following envelope items.
    // Not removing them leads to an error and events won't get displayed.
    NSMutableArray<SentryEnvelopeItem *> *allowedEnvelopeItems = [NSMutableArray new];
    for (SentryEnvelopeItem *item in envelope.items) {
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeEvent]) {
            [allowedEnvelopeItems addObject:item];
        }
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeTransaction]) {
            [allowedEnvelopeItems addObject:item];
        }
    }

    SentryEnvelope *envelopeToSend = [[SentryEnvelope alloc] initWithHeader:envelope.header
                                                                      items:allowedEnvelopeItems];

    NSError *requestError = nil;
    NSURLRequest *request = [self.requestBuilder createEnvelopeRequest:envelopeToSend
                                                                   url:self.apiURL
                                                      didFailWithError:&requestError];

    if (requestError) {
        SENTRY_LOG_ERROR(@"Unable to build envelope request with error %@", requestError);
        return;
    }

    [self.requestManager
               addRequest:request
        completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            if (error) {
                SENTRY_LOG_ERROR(@"Error while performing request %@", requestError);
            }
        }];
}

- (SentryFlushResult)flush:(NSTimeInterval)timeout
{
    // Empty on purpose
    return kSentryFlushResultSuccess;
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    // Empty on purpose
}

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity
{
    // Empty on purpose
}

#if defined(TEST) || defined(TESTCI) || defined(DEBUG)
- (void)setStartFlushCallback:(nonnull void (^)(void))callback
{
    // Empty on purpose
}

#endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

NS_ASSUME_NONNULL_END
