#import <SentryUIEventTrackerTransactionMode.h>

#if SENTRY_HAS_UIKIT

#    import <SentryDependencyContainer.h>
#    import <SentryHub+Private.h>
#    import <SentryLog.h>
#    import <SentrySDK+Private.h>
#    import <SentrySDK.h>
#    import <SentryScope.h>
#    import <SentrySpanId.h>
#    import <SentrySpanOperations.h>
#    import <SentryTraceOrigins.h>
#    import <SentryTracer.h>
#    import <SentryTransactionContext+Private.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryUIEventTrackerTransactionMode ()

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
    accessibilityIdentifier:(NSString *)accessibilityIdentifier
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
        [currentActiveTransaction dispatchIdleTimeout];
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
                                                origin:SentryTraceOriginUIEventTracker];

    __block SentryTracer *transaction;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        BOOL ongoingScreenLoadTransaction
            = span != nil && [span.operation isEqualToString:SentrySpanOperationUILoad];
        BOOL ongoingManualTransaction = span != nil
            && ![span.operation isEqualToString:SentrySpanOperationUILoad]
            && ![span.operation containsString:SentrySpanOperationUIAction];

        BOOL bindToScope = !ongoingScreenLoadTransaction && !ongoingManualTransaction;

        transaction = [SentrySDK.currentHub
            startTransactionWithContext:context
                            bindToScope:bindToScope
                  customSamplingContext:@{}
                          configuration:[SentryTracerConfiguration configurationWithBlock:^(
                                            SentryTracerConfiguration *config) {
                              config.idleTimeout = self.idleTimeout;
                              config.waitForChildren = YES;
                          }]];

        SENTRY_LOG_DEBUG(@"Automatically started a new transaction with name: "
                         @"%@, bindToScope: %@",
            action, bindToScope ? @"YES" : @"NO");
    }];

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
