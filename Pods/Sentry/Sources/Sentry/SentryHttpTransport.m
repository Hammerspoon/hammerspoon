#import "SentryHttpTransport.h"
#import "SentryClientReport.h"
#import "SentryDataCategory.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDiscardReasonMapper.h"
#import "SentryDiscardedEvent.h"
#import "SentryDsn.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryEvent.h"
#import "SentryFileManager.h"
#import "SentryLogC.h"
#import "SentryNSURLRequestBuilder.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"

#if !TARGET_OS_WATCH
#    import "SentryReachability.h"
#endif // !TARGET_OS_WATCH

@interface SentryHttpTransport ()
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
@property (nonatomic, strong) id<SentryCurrentDateProvider> dateProvider;

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
@property (nullable, nonatomic, strong) void (^startFlushCallback)(void);
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

/**
 * Relay expects the discarded events split by data category and reason; see
 * https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
 * We could use nested dictionaries, but instead, we use a dictionary with key
 * @c data-category:reason and value @c SentryDiscardedEvent because it's easier to read and type.
 */
@property (nonatomic, strong)
    NSMutableDictionary<NSString *, SentryDiscardedEvent *> *discardedEvents;

@property (nonatomic, strong) NSMutableArray<SentryEnvelope *> *notStoredEnvelopes;

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
               dateProvider:(id<SentryCurrentDateProvider>)dateProvider
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
        self.dateProvider = dateProvider;
        self.dispatchGroup = dispatch_group_create();
        _isSending = NO;
        _isFlushing = NO;
        self.discardedEvents = [NSMutableDictionary new];
        self.notStoredEnvelopes = [NSMutableArray new];
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
        SENTRY_LOG_WARN(@"RateLimit is active for all envelope items.");
        return;
    }

    SentryEnvelope *envelopeToStore = [self addClientReportTo:envelope];

    // With this we accept the a tradeoff. We might loose some envelopes when a hard crash happens,
    // because this being done on a background thread, but instead we don't block the calling
    // thread, which could be the main thread.
    __weak SentryHttpTransport *weakSelf = self;
    [self.dispatchQueue dispatchAsyncWithBlock:^{
        NSString *path = [weakSelf.fileManager storeEnvelope:envelopeToStore];
        if (path == nil) {
            SENTRY_LOG_DEBUG(@"Could not store envelope. Schedule for sending.");
            @synchronized(weakSelf.notStoredEnvelopes) {
                [weakSelf.notStoredEnvelopes addObject:envelopeToStore];
            }
        }
        [weakSelf sendAllCachedEnvelopes];
    }];
}

- (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [self.fileManager storeEnvelope:envelope];
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

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
- (void)setStartFlushCallback:(void (^)(void))callback
{
    _startFlushCallback = callback;
}
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

- (SentryFlushResult)flush:(NSTimeInterval)timeout
{
    // Calculate the dispatch time of the flush duration as early as possible to guarantee an exact
    // flush duration. Any code up to the dispatch_group_wait can take a couple of ms, adding up to
    // the flush duration.
    dispatch_time_t delta = (int64_t)(timeout * (NSTimeInterval)NSEC_PER_SEC);
    dispatch_time_t dispatchTimeout = dispatch_time(DISPATCH_TIME_NOW, delta);

    @synchronized(self) {
        if (_isFlushing) {
            SENTRY_LOG_DEBUG(@"Already flushing.");
            return kSentryFlushResultAlreadyFlushing;
        }

        SENTRY_LOG_DEBUG(@"Start flushing.");

        _isFlushing = YES;
        dispatch_group_enter(self.dispatchGroup);
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
        if (self.startFlushCallback != nil) {
            self.startFlushCallback();
        }
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
    }

    // We are waiting for the dispatch group below, which we leave in finished sending. As
    // sendAllCachedEnvelopes does some IO, it could block the calling thread longer than the
    // desired flush duration. Therefore, we dispatch the sendAllCachedEnvelopes async. Furthermore,
    // when calling flush directly after captureEnvelope, it could happen that SDK doesn't store the
    // envelope to disk, which happens async, before starting to flush.
    [self.dispatchQueue dispatchAsyncWithBlock:^{ [self sendAllCachedEnvelopes]; }];

    intptr_t result = dispatch_group_wait(self.dispatchGroup, dispatchTimeout);

    if (result == 0) {
        SENTRY_LOG_DEBUG(@"Finished flushing.");
        return kSentryFlushResultSuccess;
    } else {
        SENTRY_LOG_WARN(@"Flushing timed out.");
        return kSentryFlushResultTimedOut;
    }
}

/**
 * SentryEnvelopeRateLimitDelegate.
 */
- (void)envelopeItemDropped:(SentryEnvelopeItem *)envelopeItem
               withCategory:(SentryDataCategory)dataCategory;
{
    SENTRY_LOG_WARN(@"Envelope item dropped due to exceeding rate limit. Category: %@",
        nameForSentryDataCategory(dataCategory));
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
        if (self.isSending) {
            SENTRY_LOG_DEBUG(@"Already sending.");
            return;
        }
        if (![self.requestManager isReady]) {
            SENTRY_LOG_DEBUG(@"Request manager not ready.");
            return;
        }
        self.isSending = YES;
    }

    SentryEnvelope *envelope;
    NSString *envelopeFilePath;

    @synchronized(self.notStoredEnvelopes) {
        if (self.notStoredEnvelopes.count > 0) {
            envelope = self.notStoredEnvelopes[0];
            [self.notStoredEnvelopes removeObjectAtIndex:0];
        }
    }

    if (envelope == nil) {
        SentryFileContents *envelopeFileContents = [self.fileManager getOldestEnvelope];
        if (nil == envelopeFileContents) {
            SENTRY_LOG_DEBUG(@"No envelopes left to send.");
            [self finishedSending];
            return;
        }

        envelopeFilePath = envelopeFileContents.path;

        envelope = [SentrySerialization envelopeWithData:envelopeFileContents.contents];
        if (nil == envelope) {
            SENTRY_LOG_DEBUG(@"Envelope contained no deserializable data.");
            [self deleteEnvelopeAndSendNext:envelopeFilePath];
            return;
        }
    }

    SentryEnvelope *rateLimitedEnvelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];
    if (rateLimitedEnvelope.items.count == 0) {
        SENTRY_LOG_DEBUG(@"Envelope had no rate-limited items, nothing to send.");
        [self deleteEnvelopeAndSendNext:envelopeFilePath];
        return;
    }

    // We must set sentAt as close as possible to the transmission of the envelope to Sentry.
    rateLimitedEnvelope.header.sentAt = [self.dateProvider date];

    NSError *requestError = nil;
    NSURLRequest *request = [self.requestBuilder createEnvelopeRequest:rateLimitedEnvelope
                                                                   dsn:self.options.parsedDsn
                                                      didFailWithError:&requestError];

    if (nil == request || nil != requestError) {
        if (nil != requestError) {
            SENTRY_LOG_DEBUG(@"Failed to build request: %@.", requestError);
        }
        [self recordLostEventFor:rateLimitedEnvelope.items];
        [self deleteEnvelopeAndSendNext:envelopeFilePath];
        return;
    } else {
        [self sendEnvelope:rateLimitedEnvelope envelopePath:envelopeFilePath request:request];
    }
}

- (void)deleteEnvelopeAndSendNext:(nullable NSString *)envelopePath
{
    SENTRY_LOG_DEBUG(@"Deleting envelope and sending next.");
    if (envelopePath != nil) {
        [self.fileManager removeFileAtPath:envelopePath];
    }
    @synchronized(self) {
        self.isSending = NO;
    }

    __weak SentryHttpTransport *weakSelf = self;
    dispatch_block_t block = ^{
        if (weakSelf == nil) {
            return;
        }
        [weakSelf sendAllCachedEnvelopes];
    };
    [self.dispatchQueue dispatchAfter:self.cachedEnvelopeSendDelay block:block];
}

- (void)sendEnvelope:(SentryEnvelope *)envelope
        envelopePath:(NSString *_Nullable)envelopePath
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

            if (error && response.statusCode != 429) {
                SENTRY_LOG_DEBUG(@"Request error other than rate limit: %@", error);
                [weakSelf recordLostEventFor:envelope.items];
            }

            if (response == nil) {
                SENTRY_LOG_DEBUG(@"No internet connection.");
                [weakSelf finishedSending];
                return;
            }

            [weakSelf.rateLimits update:response];

            if (response.statusCode == 200) {
                SENTRY_LOG_DEBUG(@"Envelope sent successfully!");
                [weakSelf deleteEnvelopeAndSendNext:envelopePath];
                return;
            }

            SENTRY_LOG_DEBUG(@"Received non-200 response code: %li", (long)response.statusCode);
            [weakSelf finishedSending];
        }];
}

- (void)finishedSending
{
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
        NSDictionary *_Nullable transactionJson =
            [SentrySerialization deserializeDictionaryFromJsonData:envelopeItem.data];
        if (transactionJson == nil) {
            return;
        }
        NSArray *spans = transactionJson[@"spans"] ?: [NSArray array];
        [self recordLostEvent:kSentryDataCategorySpan reason:reason quantity:spans.count + 1];
    }
}

@end
