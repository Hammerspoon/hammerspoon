#import <SentryUIEventTrackerTransactionMode.h>

#if SENTRY_HAS_UIKIT

#    import "SentrySwift.h"
#    import <SentryDependencyContainer.h>
#    import <SentryHub+Private.h>
#    import <SentryLogC.h>
#    import <SentrySDK+Private.h>
#    import <SentrySDK.h>
#    import <SentryScope.h>
#    import <SentrySpanId.h>
#    import <SentrySpanOperation.h>
#    import <SentryTraceOrigin.h>
#    import <SentryTracer.h>
#    import <SentryTransactionContext+Private.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryUIEventTrackerTransactionMode ()

@property (nonatomic, assign) NSTimeInterval idleTimeout;
@property (nullable, nonatomic, strong) NSMutableArray<SentryTracer *> *activeTransactions;

@end

@implementation SentryUIEventTrackerTransactionMode

- (instancetype)initWithIdleTimeout:(NSTimeInterval)idleTimeout
{
    if (self = [super init]) {
        self.idleTimeout = idleTimeout;
        self.activeTransactions = [NSMutableArray new];
    }
    return self;
}

- (void)handleUIEvent:(NSString *)action
                  operation:(NSString *)operation
    accessibilityIdentifier:(nullable NSString *)accessibilityIdentifier
{

    // There might be more active transactions stored, but only the last one might still be
    // active with a timeout. The others are already waiting for their children to finish
    // without a timeout.
    SentryTracer *currentActiveTransaction;
    @synchronized(self.activeTransactions) {
        currentActiveTransaction = self.activeTransactions.lastObject;
    }

    BOOL sameAction = [currentActiveTransaction.transactionContext.name isEqualToString:action];
    if (sameAction) {
        SENTRY_LOG_DEBUG(@"Dispatching idle timeout for transaction with span id %@",
            currentActiveTransaction.spanId.sentrySpanIdString);
        [currentActiveTransaction startIdleTimeout];
        return;
    }

    [currentActiveTransaction finish];

    if (currentActiveTransaction) {
        SENTRY_LOG_DEBUG(@"Finished transaction %@ (span ID %@)",
            currentActiveTransaction.transactionContext.name,
            currentActiveTransaction.spanId.sentrySpanIdString);
    }

    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithName:action
                                            nameSource:kSentryTransactionNameSourceComponent
                                             operation:operation
                                                origin:SentryTraceOriginAutoUiEventTracker];

    id<SentrySpan> _Nullable currentSpan = [SentrySDK.currentHub.scope span];
    BOOL ongoingScreenLoadTransaction = false;
    BOOL ongoingManualTransaction = false;
    if (currentSpan != nil) {
        ongoingScreenLoadTransaction =
            [currentSpan.operation isEqualToString:SentrySpanOperationUiLoad];
        ongoingManualTransaction
            = ![currentSpan.operation isEqualToString:SentrySpanOperationUiLoad]
            && ![currentSpan.operation containsString:SentrySpanOperationUiAction];
    }

    // If there is an ongoing transaction on the scope, we don’t need to start a UI event
    // transaction because it won’t have any child spans. Only transactions bound to the scope
    // automatically receive child spans. As a result, the UI event transaction would time out and
    // be discarded by the tracer due to the lack of children.
    BOOL ongoingTransaction = ongoingScreenLoadTransaction || ongoingManualTransaction;
    if (ongoingTransaction) {
        SENTRY_LOG_DEBUG(@"Not starting a new UI event transaction because there is already an "
                         @"ongoing transaction bound to the scope.");
        return;
    }

    __block SentryTracer *transaction = [SentrySDK.currentHub
        startTransactionWithContext:context
                        bindToScope:YES
              customSamplingContext:@{}
                      configuration:[SentryTracerConfiguration configurationWithBlock:^(
                                        SentryTracerConfiguration *config) {
                          config.idleTimeout = self.idleTimeout;
                          config.waitForChildren = YES;
                      }]];

    SENTRY_LOG_DEBUG(@"Automatically started a new transaction with name: %@", action);

    if (accessibilityIdentifier) {
        [transaction setTagValue:accessibilityIdentifier forKey:@"accessibilityIdentifier"];
    }

    transaction.finishCallback = ^(SentryTracer *tracer) {
        @synchronized(self.activeTransactions) {
            [self.activeTransactions removeObject:tracer];
            SENTRY_LOG_DEBUG(@"Active transactions after removing tracer for span ID %@: %@",
                tracer.spanId.sentrySpanIdString, self.activeTransactions);
        }
    };
    @synchronized(self.activeTransactions) {
        SENTRY_LOG_DEBUG(@"Adding transaction %@ to list of active transactions (currently %@)",
            transaction.spanId.sentrySpanIdString, self.activeTransactions);
        [self.activeTransactions addObject:transaction];
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
