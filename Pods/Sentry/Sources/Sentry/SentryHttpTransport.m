#import "SentryHttpTransport.h"
#import "SentryClientReport.h"
#import "SentryDataCategory.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDiscardReasonMapper.h"
#import "SentryDiscardedEvent.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDsn.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryEvent.h"
#import "SentryFileContents.h"
#import "SentryFileManager.h"
#import "SentryLog.h"
#import "SentryNSURLRequest.h"
#import "SentryNSURLRequestBuilder.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"

#if !TARGET_OS_WATCH
#    import "SentryReachability.h"
#endif // !TARGET_OS_WATCH

@interface
SentryHttpTransport ()
#if SENTRY_HAS_REACHABILITY
    <SentryReachabilityObserver>
#endif // !TARGET_OS_WATCH

@property (nonatomic, readonly) NSTimeInterval cachedEnvelopeSendDelay;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) id<SentryRequestManager> requestManager;
@property (nonatomic, strong) SentryNSURLRequestBuilder *requestBuilder;
@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryRateLimits> rateLimits;
@property (nonatomic, strong) SentryEnvelopeRateLimit *envelopeRateLimit;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) dispatch_group_t dispatchGroup;

#if defined(TEST) || defined(TESTCI) || defined(DEBUG)
@property (nullable, nonatomic, strong) void (^startFlushCallback)(void);
#endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

/**
 * Relay expects the discarded events split by data category and reason; see
 * https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
 * We could use nested dictionaries, but instead, we use a dictionary with key
 * @c data-category:reason and value @c SentryDiscardedEvent because it's easier to read and type.
 */
@property (nonatomic, strong)
    NSMutableDictionary<NSString *, SentryDiscardedEvent *> *discardedEvents;

/**
 * Synching with a dispatch queue to have concurrent reads and writes as barrier blocks is roughly
 * 30% slower than using atomic here.
 */
@property (atomic) BOOL isSending;

@property (atomic) BOOL isFlushing;

@end

@implementation SentryHttpTransport

- (id)initWithOptions:(SentryOptions *)options
    cachedEnvelopeSendDelay:(NSTimeInterval)cachedEnvelopeSendDelay
                fileManager:(SentryFileManager *)fileManager
             requestManager:(id<SentryRequestManager>)requestManager
             requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
                 rateLimits:(id<SentryRateLimits>)rateLimits
          envelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
       dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.options = options;
        _cachedEnvelopeSendDelay = cachedEnvelopeSendDelay;
        self.requestManager = requestManager;
        self.requestBuilder = requestBuilder;
        self.fileManager = fileManager;
        self.rateLimits = rateLimits;
        self.envelopeRateLimit = envelopeRateLimit;
        self.dispatchQueue = dispatchQueueWrapper;
        self.dispatchGroup = dispatch_group_create();
        _isSending = NO;
        _isFlushing = NO;
        self.discardedEvents = [NSMutableDictionary new];
        [self.envelopeRateLimit setDelegate:self];
        [self.fileManager setDelegate:self];

        [self sendAllCachedEnvelopes];

#if SENTRY_HAS_REACHABILITY
        [SentryDependencyContainer.sharedInstance.reachability addObserver:self];
#endif // !TARGET_OS_WATCH
    }
    return self;
}

#if SENTRY_HAS_REACHABILITY
- (void)connectivityChanged:(BOOL)connected typeDescription:(nonnull NSString *)typeDescription
{
    if (connected) {
        SENTRY_LOG_DEBUG(@"Internet connection is back.");
        [self sendAllCachedEnvelopes];
    } else {
        SENTRY_LOG_DEBUG(@"Lost internet connection.");
    }
}

- (void)dealloc
{
    [SentryDependencyContainer.sharedInstance.reachability removeObserver:self];
}
#endif // !TARGET_OS_WATCH

- (void)sendEnvelope:(SentryEnvelope *)envelope
{
    envelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];

    if (envelope.items.count == 0) {
        SENTRY_LOG_DEBUG(@"RateLimit is active for all envelope items.");
        return;
    }

    SentryEnvelope *envelopeToStore = [self addClientReportTo:envelope];

    // With this we accept the a tradeoff. We might loose some envelopes when a hard crash happens,
    // because this being done on a background thread, but instead we don't block the calling
    // thread, which could be the main thread.
    __weak SentryHttpTransport *weakSelf = self;
    [self.dispatchQueue dispatchAsyncWithBlock:^{
        [weakSelf.fileManager storeEnvelope:envelopeToStore];
        [weakSelf sendAllCachedEnvelopes];
    }];
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    [self recordLostEvent:category reason:reason quantity:1];
}

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity
{
    if (!self.options.sendClientReports) {
        return;
    }

    NSString *key = [NSString stringWithFormat:@"%@:%@", nameForSentryDataCategory(category),
                              nameForSentryDiscardReason(reason)];

    @synchronized(self.discardedEvents) {
        SentryDiscardedEvent *event = self.discardedEvents[key];
        if (event != nil) {
            quantity = event.quantity + 1;
        }

        event = [[SentryDiscardedEvent alloc] initWithReason:reason
                                                    category:category
                                                    quantity:quantity];

        self.discardedEvents[key] = event;
    }
}

#if defined(TEST) || defined(TESTCI) || defined(DEBUG)
- (void)setStartFlushCallback:(void (^)(void))callback
{
    _startFlushCallback = callback;
}
#endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

- (SentryFlushResult)flush:(NSTimeInterval)timeout
{
    // Calculate the dispatch time of the flush duration as early as possible to guarantee an exact
    // flush duration. Any code up to the dispatch_group_wait can take a couple of ms, adding up to
    // the flush duration.
    dispatch_time_t delta = (int64_t)(timeout * (NSTimeInterval)NSEC_PER_SEC);
    dispatch_time_t dispatchTimeout = dispatch_time(DISPATCH_TIME_NOW, delta);

    // Double-Checked Locking to avoid acquiring unnecessary locks.
    if (_isFlushing) {
        SENTRY_LOG_DEBUG(@"Already flushing.");
        return kSentryFlushResultAlreadyFlushing;
    }

    @synchronized(self) {
        if (_isFlushing) {
            SENTRY_LOG_DEBUG(@"Already flushing.");
            return kSentryFlushResultAlreadyFlushing;
        }

        SENTRY_LOG_DEBUG(@"Start flushing.");

        _isFlushing = YES;
        dispatch_group_enter(self.dispatchGroup);
#if defined(TEST) || defined(TESTCI) || defined(DEBUG)
        if (self.startFlushCallback != nil) {
            self.startFlushCallback();
        }
#endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)
    }

    // We are waiting for the dispatch group below, which we leave in finished sending. As
    // sendAllCachedEnvelopes does some IO, it could block the calling thread longer than the
    // desired flush duration. Therefore, we dispatch the sendAllCachedEnvelopes async. Furthermore,
    // when calling flush directly after captureEnvelope, it could happen that SDK doesn't store the
    // envelope to disk, which happens async, before starting to flush.
    [self.dispatchQueue dispatchAsyncWithBlock:^{ [self sendAllCachedEnvelopes]; }];

    intptr_t result = dispatch_group_wait(self.dispatchGroup, dispatchTimeout);

    @synchronized(self) {
        self.isFlushing = NO;
    }

    if (result == 0) {
        SENTRY_LOG_DEBUG(@"Finished flushing.");
        return kSentryFlushResultSuccess;
    } else {
        SENTRY_LOG_DEBUG(@"Flushing timed out.");
        return kSentryFlushResultTimedOut;
    }
}

/**
 * SentryEnvelopeRateLimitDelegate.
 */
- (void)envelopeItemDropped:(SentryEnvelopeItem *)envelopeItem
               withCategory:(SentryDataCategory)dataCategory;
{
    [self recordLostEvent:dataCategory reason:kSentryDiscardReasonRateLimitBackoff];
    [self recordLostSpans:envelopeItem reason:kSentryDiscardReasonRateLimitBackoff];
}

/**
 * SentryFileManagerDelegate.
 */
- (void)envelopeItemDeleted:(SentryEnvelopeItem *)envelopeItem
               withCategory:(SentryDataCategory)dataCategory
{
    [self recordLostEvent:dataCategory reason:kSentryDiscardReasonCacheOverflow];
    [self recordLostSpans:envelopeItem reason:kSentryDiscardReasonCacheOverflow];
}

#pragma mark private methods

- (SentryEnvelope *)addClientReportTo:(SentryEnvelope *)envelope
{
    if (!self.options.sendClientReports) {
        return envelope;
    }

    NSArray<SentryDiscardedEvent *> *events;

    @synchronized(self.discardedEvents) {
        if (self.discardedEvents.count == 0) {
            return envelope;
        }

        events = [self.discardedEvents allValues];
        [self.discardedEvents removeAllObjects];
    }

    SentryClientReport *clientReport = [[SentryClientReport alloc] initWithDiscardedEvents:events];

    SentryEnvelopeItem *clientReportEnvelopeItem =
        [[SentryEnvelopeItem alloc] initWithClientReport:clientReport];

    NSMutableArray<SentryEnvelopeItem *> *currentItems =
        [[NSMutableArray alloc] initWithArray:envelope.items];
    [currentItems addObject:clientReportEnvelopeItem];

    return [[SentryEnvelope alloc] initWithHeader:envelope.header items:currentItems];
}

- (void)sendAllCachedEnvelopes
{
    SENTRY_LOG_DEBUG(@"sendAllCachedEnvelopes start.");

    @synchronized(self) {
        if (self.isSending || ![self.requestManager isReady]) {
            SENTRY_LOG_DEBUG(@"Already sending.");
            return;
        }
        self.isSending = YES;
    }

    SentryFileContents *envelopeFileContents = [self.fileManager getOldestEnvelope];
    if (nil == envelopeFileContents) {
        SENTRY_LOG_DEBUG(@"No envelopes left to send.");
        [self finishedSending];
        return;
    }

    SentryEnvelope *envelope = [SentrySerialization envelopeWithData:envelopeFileContents.contents];
    if (nil == envelope) {
        [self deleteEnvelopeAndSendNext:envelopeFileContents.path];
        return;
    }

    SentryEnvelope *rateLimitedEnvelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];
    if (rateLimitedEnvelope.items.count == 0) {
        [self deleteEnvelopeAndSendNext:envelopeFileContents.path];
        return;
    }

    // We must set sentAt as close as possible to the transmission of the envelope to Sentry.
    rateLimitedEnvelope.header.sentAt = SentryDependencyContainer.sharedInstance.dateProvider.date;

    NSError *requestError = nil;
    NSURLRequest *request = [self.requestBuilder createEnvelopeRequest:rateLimitedEnvelope
                                                                   dsn:self.options.parsedDsn
                                                      didFailWithError:&requestError];

    if (nil != requestError) {
        [self recordLostEventFor:rateLimitedEnvelope.items];
        [self deleteEnvelopeAndSendNext:envelopeFileContents.path];
        return;
    } else {
        [self sendEnvelope:rateLimitedEnvelope
              envelopePath:envelopeFileContents.path
                   request:request];
    }
}

- (void)deleteEnvelopeAndSendNext:(NSString *)envelopePath
{
    SENTRY_LOG_DEBUG(@"Deleting envelope and sending next.");
    [self.fileManager removeFileAtPath:envelopePath];
    @synchronized(self) {
        self.isSending = NO;
    }

    __weak SentryHttpTransport *weakSelf = self;
    [self.dispatchQueue dispatchAfter:self.cachedEnvelopeSendDelay
                                block:^{
                                    if (weakSelf == nil) {
                                        return;
                                    }
                                    [weakSelf sendAllCachedEnvelopes];
                                }];
}

- (void)sendEnvelope:(SentryEnvelope *)envelope
        envelopePath:(NSString *)envelopePath
             request:(NSURLRequest *)request
{
    __weak SentryHttpTransport *weakSelf = self;
    [self.requestManager
               addRequest:request
        completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            if (weakSelf == nil) {
                SENTRY_LOG_DEBUG(@"WeakSelf is nil. Not doing anything.");
                return;
            }

            // If the response is not nil we had an internet connection.
            if (error && response.statusCode != 429) {
                [weakSelf recordLostEventFor:envelope.items];
            }

            if (nil != response) {
                [weakSelf.rateLimits update:response];
                [weakSelf deleteEnvelopeAndSendNext:envelopePath];
            } else {
                SENTRY_LOG_DEBUG(@"No internet connection.");
                [weakSelf finishedSending];
            }
        }];
}

- (void)finishedSending
{
    SENTRY_LOG_DEBUG(@"Finished sending.");
    @synchronized(self) {
        self.isSending = NO;
        if (self.isFlushing) {
            SENTRY_LOG_DEBUG(@"Stop flushing.");
            self.isFlushing = NO;
            dispatch_group_leave(self.dispatchGroup);
        }
    }
}

- (void)recordLostEventFor:(NSArray<SentryEnvelopeItem *> *)items
{
    for (SentryEnvelopeItem *item in items) {
        NSString *itemType = item.header.type;
        // We don't want to record a lost event when it's a client report.
        // It's fine to drop it silently.
        if ([itemType isEqualToString:SentryEnvelopeItemTypeClientReport]) {
            continue;
        }
        SentryDataCategory category = sentryDataCategoryForEnvelopItemType(itemType);
        [self recordLostEvent:category reason:kSentryDiscardReasonNetworkError];
        [self recordLostSpans:item reason:kSentryDiscardReasonNetworkError];
    }
}

- (void)recordLostSpans:(SentryEnvelopeItem *)envelopeItem reason:(SentryDiscardReason)reason
{
    if ([SentryEnvelopeItemTypeTransaction isEqualToString:envelopeItem.header.type]) {
        NSDictionary *transactionJson =
            [SentrySerialization deserializeEventEnvelopeItem:envelopeItem.data];
        if (transactionJson == nil) {
            return;
        }
        NSArray *spans = transactionJson[@"spans"] ?: [NSArray array];
        [self recordLostEvent:kSentryDataCategorySpan reason:reason quantity:spans.count + 1];
    }
}

@end
