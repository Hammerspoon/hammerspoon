#import "SentrySwizzleWrapper.h"
#import <SentryHub+Private.h>
#import <SentryLog.h>
#import <SentrySDK+Private.h>
#import <SentrySDK.h>
#import <SentryScope.h>
#import <SentrySpanId.h>
#import <SentrySpanOperations.h>
#import <SentrySpanProtocol.h>
#import <SentryTracer.h>
#import <SentryTransactionContext+Private.h>
#import <SentryUIEventTracker.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryUIEventTrackerSwizzleSendAction
    = @"SentryUIEventTrackerSwizzleSendAction";

@interface
SentryUIEventTracker ()

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, assign) NSTimeInterval idleTimeout;
@property (nullable, nonatomic, strong) NSMutableArray<SentryTracer *> *activeTransactions;

@end

#endif

@implementation SentryUIEventTracker

#if SENTRY_HAS_UIKIT

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper
                  dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                           idleTimeout:(NSTimeInterval)idleTimeout
{
    if (self = [super init]) {
        self.swizzleWrapper = swizzleWrapper;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.idleTimeout = idleTimeout;
        self.activeTransactions = [NSMutableArray new];
    }
    return self;
}

- (void)start
{
    [self.swizzleWrapper
        swizzleSendAction:^(NSString *action, id target, id sender, UIEvent *event) {
            if (target == nil) {
                SENTRY_LOG_DEBUG(@"Target was nil for action %@; won't capture in transaction "
                                 @"(sender: %@; event: %@)",
                    action, sender, event);
                return;
            }

            if (sender == nil) {
                SENTRY_LOG_DEBUG(@"Sender was nil for action %@; won't capture in transaction "
                                 @"(target: %@; event: %@)",
                    action, sender, event);
                return;
            }

            // When using an application delegate with SwiftUI we receive touch events here, but
            // the target class name looks something like
            // _TtC7SwiftUIP33_64A26C7A8406856A733B1A7B593971F711Coordinator.primaryActionTriggered,
            // which is unacceptable for a transaction name. Ideally, we should somehow shorten
            // the long name.

            NSString *targetClass = NSStringFromClass([target class]);
            if ([targetClass containsString:@"SwiftUI"]) {
                SENTRY_LOG_DEBUG(@"Won't record transaction for SwiftUI target event.");
                return;
            }

            NSString *transactionName = [self getTransactionName:action target:targetClass];

            // There might be more active transactions stored, but only the last one might still be
            // active with a timeout. The others are already waiting for their children to finish
            // without a timeout.
            SentryTracer *currentActiveTransaction;
            @synchronized(self.activeTransactions) {
                currentActiveTransaction = self.activeTransactions.lastObject;
            }

            BOOL sameAction =
                [currentActiveTransaction.transactionContext.name isEqualToString:transactionName];
            if (sameAction) {
                SENTRY_LOG_DEBUG(@"Dispatching idle timeout for transaction with span id %@",
                    currentActiveTransaction.spanId.sentrySpanIdString);
                [currentActiveTransaction dispatchIdleTimeout];
                return;
            }

            [currentActiveTransaction finish];

            if (currentActiveTransaction) {
                SENTRY_LOG_DEBUG(@"SentryUIEventTracker finished transaction %@ (span ID %@)",
                    currentActiveTransaction.transactionContext.name,
                    currentActiveTransaction.spanId.sentrySpanIdString);
            }

            NSString *operation = [self getOperation:sender];

            SentryTransactionContext *context =
                [[SentryTransactionContext alloc] initWithName:transactionName
                                                    nameSource:kSentryTransactionNameSourceComponent
                                                     operation:operation];

            __block SentryTracer *transaction;
            [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
                BOOL ongoingScreenLoadTransaction
                    = span != nil && [span.operation isEqualToString:SentrySpanOperationUILoad];
                BOOL ongoingManualTransaction = span != nil
                    && ![span.operation isEqualToString:SentrySpanOperationUILoad]
                    && ![span.operation containsString:SentrySpanOperationUIAction];

                BOOL bindToScope = !ongoingScreenLoadTransaction && !ongoingManualTransaction;
                transaction =
                    [SentrySDK.currentHub startTransactionWithContext:context
                                                          bindToScope:bindToScope
                                                customSamplingContext:@{}
                                                          idleTimeout:self.idleTimeout
                                                 dispatchQueueWrapper:self.dispatchQueueWrapper];

                SENTRY_LOG_DEBUG(@"SentryUIEventTracker automatically started a new transaction "
                                 @"with name: %@, bindToScope: %@",
                    transactionName, bindToScope ? @"YES" : @"NO");
            }];

            if ([[sender class] isSubclassOfClass:[UIView class]]) {
                UIView *view = sender;
                if (view.accessibilityIdentifier) {
                    [transaction setTagValue:view.accessibilityIdentifier
                                      forKey:@"accessibilityIdentifier"];
                }
            }

            transaction.finishCallback = ^(SentryTracer *tracer) {
                @synchronized(self.activeTransactions) {
                    [self.activeTransactions removeObject:tracer];
                    SENTRY_LOG_DEBUG(
                        @"Active transactions after removing tracer for span ID %@: %@",
                        tracer.spanId.sentrySpanIdString, self.activeTransactions);
                }
            };
            @synchronized(self.activeTransactions) {
                SENTRY_LOG_DEBUG(
                    @"Adding transaction %@ to list of active transactions (currently %@)",
                    transaction.spanId.sentrySpanIdString, self.activeTransactions);
                [self.activeTransactions addObject:transaction];
            }
        }
                   forKey:SentryUIEventTrackerSwizzleSendAction];
}

- (void)stop
{
    [self.swizzleWrapper removeSwizzleSendActionForKey:SentryUIEventTrackerSwizzleSendAction];
}

- (NSString *)getOperation:(id)sender
{
    Class senderClass = [sender class];
    if ([senderClass isSubclassOfClass:[UIButton class]] ||
        [senderClass isSubclassOfClass:[UIBarButtonItem class]] ||
        [senderClass isSubclassOfClass:[UISegmentedControl class]] ||
        [senderClass isSubclassOfClass:[UIPageControl class]]) {
        return SentrySpanOperationUIActionClick;
    }

    return SentrySpanOperationUIAction;
}

/**
 * The action is an Objective-C selector and might look weird for Swift developers. Therefore we
 * convert the selector to a Swift appropriate format aligned with the Swift #selector syntax.
 * method:first:second:third: gets converted to method(first:second:third:)
 */
- (NSString *)getTransactionName:(NSString *)action target:(NSString *)target
{
    NSArray<NSString *> *components = [action componentsSeparatedByString:@":"];
    if (components.count > 2) {
        NSMutableString *result =
            [[NSMutableString alloc] initWithFormat:@"%@.%@(", target, components.firstObject];

        for (int i = 1; i < (components.count - 1); i++) {
            [result appendFormat:@"%@:", components[i]];
        }

        [result appendFormat:@")"];

        return result;
    }

    return [NSString stringWithFormat:@"%@.%@", target, components.firstObject];
}

NS_ASSUME_NONNULL_END

#endif

NS_ASSUME_NONNULL_BEGIN

+ (BOOL)isUIEventOperation:(NSString *)operation
{
    if ([operation isEqualToString:SentrySpanOperationUIAction]) {
        return YES;
    }
    if ([operation isEqualToString:SentrySpanOperationUIActionClick]) {
        return YES;
    }
    return NO;
}

@end

NS_ASSUME_NONNULL_END
