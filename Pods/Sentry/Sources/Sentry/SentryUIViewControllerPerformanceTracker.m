#import "SentryUIViewControllerPerformanceTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDependencyContainer.h"
#    import "SentryHub.h"
#    import "SentryLogC.h"
#    import "SentryOptions.h"
#    import "SentryPerformanceTracker.h"
#    import "SentrySDK+Private.h"
#    import "SentrySpanId.h"
#    import "SentrySpanOperation.h"
#    import "SentrySwift.h"
#    import "SentryTimeToDisplayTracker.h"
#    import "SentryTraceOrigin.h"
#    import "SentryTracer.h"
#    import "SentryWeakMap.h"
#    import <SentryInAppLogic.h>
#    import <UIKit/UIKit.h>
#    import <objc/runtime.h>

// In a previous implementation, we used associated objects to store the time to display tracker,
// spanId, spans in execution, and layout subview spanId. However, this approach was prone to
// memory leaks and crashes due to accessing associated objects from different threads.
//
// See https://github.com/getsentry/sentry-cocoa/issues/5087 for reference.
//
// To address these issues, we switched to using a NSMapTable to store these values.
// This approach provides the following benefits:
//
// 1. Weak references to the keys: The NSMapTable allows us to store weak references to the keys,
//    which means we don't need to remove the entries when the UIViewController is deallocated.
//
// 2. Thread safety: The NSMapTable is thread-safe, which means we can access it from different
//    threads without the need for additional synchronization.
//
// Using a NSMapTable allows weak references to the keys, which means we don't need to remove the
// entries when the UIViewController is deallocated.
//
// DISCUSSION FROM NSMAPTABLE:
// Use of weak-to-strong map tables is not recommended. The strong values for weak keys which get
// zeroed out continue to be maintained until the map table resizes itself.
//
// To avoid this issue, we will prune the maps when we access them. This means that we will
// remove any entries with weak keys that have been deallocated. This will ensure that we don't
// keep any references to deallocated objects in the map tables and have a memory leak.

@interface SentryUIViewControllerPerformanceTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;
@property (nullable, nonatomic, weak) SentryTimeToDisplayTracker *currentTTDTracker;
@property (nonatomic, strong, readonly) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@property (nonatomic, strong)
    SentryWeakMap<UIViewController *, SentryTimeToDisplayTracker *> *ttdTrackers;
@property (nonatomic, strong) SentryWeakMap<UIViewController *, SentrySpanId *> *spanIds;
@property (nonatomic, strong)
    SentryWeakMap<UIViewController *, NSMutableSet<NSString *> *> *spansInExecution;
@property (nonatomic, strong)
    SentryWeakMap<UIViewController *, SentrySpanId *> *layoutSubviewSpanIds;

@end

@implementation SentryUIViewControllerPerformanceTracker

- (instancetype)initWithTracker:(SentryPerformanceTracker *)tracker
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    if (self = [super init]) {
        self.tracker = tracker;

        SentryOptions *options = [SentrySDK options];
        self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                            inAppExcludes:options.inAppExcludes];

        _alwaysWaitForFullDisplay = NO;
        _dispatchQueueWrapper = dispatchQueueWrapper;

        _ttdTrackers = [[SentryWeakMap alloc] init];
        _spanIds = [[SentryWeakMap alloc] init];
        _spansInExecution = [[SentryWeakMap alloc] init];
        _layoutSubviewSpanIds = [[SentryWeakMap alloc] init];
    }
    return self;
}

- (void)viewControllerLoadView:(UIViewController *)controller
              callbackToOrigin:(void (^)(void))callbackToOrigin
{
    if (![self.inAppLogic isClassInApp:[controller class]]) {
        SENTRY_LOG_DEBUG(
            @"Won't track view controller that is not part of the app bundle: %@.", controller);
        callbackToOrigin();
        return;
    }

    SentryOptions *options = [SentrySDK options];

    if ([SentrySwizzleClassNameExclude
            shouldExcludeClassWithClassName:NSStringFromClass([controller class])
                   swizzleClassNameExcludes:options.swizzleClassNameExcludes]) {
        SENTRY_LOG_DEBUG(@"Won't track view controller because it's excluded with the option "
                         @"swizzleClassNameExcludes: %@",
            controller);
        callbackToOrigin();
        return;
    }

    SENTRY_LOG_DEBUG(@"Tracking UIViewController.loadView for view controller: %@", controller);
    [self limitOverride:@"loadView"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SENTRY_LOG_DEBUG(@"Tracking loadView for view controller: %@", controller);
                       [self startRootSpanFor:controller];
                       [self measurePerformance:@"loadView"
                                         target:controller
                               callbackToOrigin:callbackToOrigin];
                   }];
}

- (void)viewControllerViewDidLoad:(UIViewController *)controller
                 callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(@"Tracking UIViewController.viewDidLoad for view controller: %@", controller);
    [self limitOverride:@"viewDidLoad"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SENTRY_LOG_DEBUG(
                           @"Tracking viewDidLoad for view controller: %@", controller);
                       [self startRootSpanFor:controller];
                       [self measurePerformance:@"viewDidLoad"
                                         target:controller
                               callbackToOrigin:callbackToOrigin];
                   }];
}

- (void)startRootSpanFor:(UIViewController *)controller
{
    SENTRY_LOG_DEBUG(@"Starting root span for view controller: %@", controller);
    SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

    // If the user manually calls loadView outside the lifecycle we don't start a new transaction
    // and override the previous id stored.
    if (spanId == nil) {
        SENTRY_LOG_DEBUG(@"No active span found for view controller: %@", controller);

        // The tracker must create a new transaction and bind it to the scope when there is no
        // active span. If the user didn't call reportFullyDisplayed, the previous UIViewController
        // transaction is still bound to the scope because it waits for its children to finish,
        // including the TTFD span. Therefore, we need to finish the TTFD span so the tracer can
        // finish and remove itself from the scope. We don't need to finish the transaction because
        // we already finished it in viewControllerViewDidAppear.
        if (self.tracker.activeSpanId == nil) {
            SENTRY_LOG_DEBUG(@"Tracker has no active span, finishing TTFD tracker");
            [self.currentTTDTracker finishSpansIfNotFinished];
        }

        NSString *name = [SwiftDescriptor getViewControllerClassName:controller];
        spanId = [self.tracker startSpanWithName:name
                                      nameSource:kSentryTransactionNameSourceComponent
                                       operation:SentrySpanOperationUiLoad
                                          origin:SentryTraceOriginAutoUIViewController];

        [self setSpanIdForViewController:controller spanId:spanId];

        // If there is no active span in the queue push this transaction
        // to serve as an umbrella transaction that will capture every span
        // happening while the transaction is active.
        if (self.tracker.activeSpanId == nil) {
            SENTRY_LOG_DEBUG(@"Started new transaction with id %@ to track view controller %@.",
                spanId.sentrySpanIdString, name);
            [self.tracker pushActiveSpan:spanId];
        } else {
            SENTRY_LOG_DEBUG(@"Started child span with id %@ to track view controller %@.",
                spanId.sentrySpanIdString, name);
        }
    }

    spanId = [self getSpanIdForViewController:controller];
    SentrySpan *_Nullable vcSpan = [self.tracker getSpan:spanId];

    if (![vcSpan isKindOfClass:[SentryTracer self]]) {
        // Since TTID and TTFD are meant to the whole screen
        // we will not track child view controllers
        return;
    }

    if ([self getTimeToDisplayTrackerForController:controller]) {
        // Already tracking time to display, not creating a new tracker.
        // This may happen if user manually call `loadView` from a view controller more than once.
        SENTRY_LOG_DEBUG(
            @"Already tracking time to display for view controller %@ using tracker %@", controller,
            self.currentTTDTracker);
        return;
    }

    SentryTimeToDisplayTracker *ttdTracker =
        [self startTimeToDisplayTrackerForScreen:[SwiftDescriptor getObjectClassName:controller]
                              waitForFullDisplay:self.alwaysWaitForFullDisplay
                                          tracer:(SentryTracer *)vcSpan];

    if (ttdTracker) {
        [self setTimeToDisplayTrackerForController:controller ttdTracker:ttdTracker];
    }
}

- (void)reportFullyDisplayed
{
    SENTRY_LOG_DEBUG(@"Reporting fully displayed");
    SentryTimeToDisplayTracker *tracker = self.currentTTDTracker;
    if (tracker == nil) {
        SENTRY_LOG_DEBUG(@"No screen transaction being tracked right now.")
        return;
    }
    if (!tracker.waitForFullDisplay) {
        SENTRY_LOG_WARN(@"Transaction is not waiting for full display report. You can enable "
                        @"`enableTimeToFullDisplay` option, or use the waitForFullDisplay "
                        @"property in our `SentryTracedView` view for SwiftUI.");
        return;
    }

    // Report the fully displayed time, then discard the tracker, because it should not be used
    // after TTFD is reported.
    SENTRY_LOG_DEBUG(@"Reported fully displayed time, discarding TTFD tracker");
    [self.currentTTDTracker reportFullyDisplayed];
}

- (nullable SentryTimeToDisplayTracker *)startTimeToDisplayTrackerForScreen:(NSString *)screenName
                                                         waitForFullDisplay:(BOOL)waitForFullDisplay
                                                                     tracer:(SentryTracer *)tracer
{
    SENTRY_LOG_DEBUG(@"Starting TTFD tracker for screen: %@, waitForFullDisplay: %@, tracer: %@",
        screenName, waitForFullDisplay ? @"YES" : @"NO", tracer);
    [self.currentTTDTracker finishSpansIfNotFinished];

    SentryTimeToDisplayTracker *ttdTracker =
        [[SentryTimeToDisplayTracker alloc] initWithName:screenName
                                      waitForFullDisplay:waitForFullDisplay
                                    dispatchQueueWrapper:_dispatchQueueWrapper];

    // If the tracker did not start, it means that the tracer can be discarded.
    if ([ttdTracker startForTracer:tracer] == NO) {
        SENTRY_LOG_DEBUG(@"TTFD tracker did not start, discarding current tracker");
        self.currentTTDTracker = nil;
        return nil;
    }

    self.currentTTDTracker = ttdTracker;
    return ttdTracker;
}

- (void)viewControllerViewWillAppear:(UIViewController *)controller
                    callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(
        @"Tracking UIViewController.viewWillAppear for view controller: %@", controller);
    void (^limitOverrideBlock)(void) = ^{
        SENTRY_LOG_DEBUG(
            @"Tracking UIViewController.viewWillAppear for controller: %@", controller);
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(
                @"Not tracking UIViewController.viewWillAppear because there is no active span.");
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            SENTRY_LOG_DEBUG(@"Tracking UIViewController.viewWillAppear");
            [self.tracker measureSpanWithDescription:@"viewWillAppear"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
        [self reportInitialDisplayForController:controller];
    };

    [self limitOverride:@"viewWillAppear"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewDidAppear:(UIViewController *)controller
                   callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(
        @"Tracking UIViewController.viewDidAppear for view controller: %@", controller);
    [self finishTransaction:controller
                     status:kSentrySpanStatusOk
            lifecycleMethod:@"viewDidAppear"
           callbackToOrigin:callbackToOrigin];
}

/**
 * According to the apple docs, see
 * https://developer.apple.com/documentation/uikit/uiviewcontroller: Not all ‘will’ callback
 * methods are paired with only a ‘did’ callback method. You need to ensure that if you start a
 * process in a ‘will’ callback method, you end the process in both the corresponding ‘did’ and
 * the opposite ‘will’ callback method.
 *
 * As stated above @c viewWillAppear doesn't need to be followed by a @c viewDidAppear. A
 * @c viewWillAppear can also be followed by a @c viewWillDisappear. Therefore, we finish the
 * transaction in
 * @c viewWillDisappear, if it wasn't already finished in @c viewDidAppear.
 */
- (void)viewControllerViewWillDisappear:(UIViewController *)controller
                       callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(
        @"Tracking UIViewController.viewWillDisappear for view controller: %@", controller);
    [self finishTransaction:controller
                     status:kSentrySpanStatusCancelled
            lifecycleMethod:@"viewWillDisappear"
           callbackToOrigin:callbackToOrigin];
}

- (void)finishTransaction:(UIViewController *)controller
                   status:(SentrySpanStatus)status
          lifecycleMethod:(NSString *)lifecycleMethod
         callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(@"Finishing transaction for view controller: %@", controller);
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(@"Not tracking UIViewController.%@ because there is no active span.",
                lifecycleMethod);
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            [self.tracker measureSpanWithDescription:lifecycleMethod
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
        id<SentrySpan> vcSpan = [self.tracker getSpan:spanId];
        // If the current controller span has no parent,
        // it means it is the root transaction and need to be pop from the queue.
        if (vcSpan.parentSpanId == nil) {
            SENTRY_LOG_DEBUG(@"Popping active span for controller: %@", controller);
            [self.tracker popActiveSpan];
        }

        // If we are still tracking this UIViewController finish the transaction
        // and remove associated span id.
        SENTRY_LOG_DEBUG(@"Finishing span for view controller: %@", controller);
        [self.tracker finishSpan:spanId withStatus:status];
        [self setSpanIdForViewController:controller spanId:nil];
    };

    [self limitOverride:lifecycleMethod
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewWillLayoutSubViews:(UIViewController *)controller
                            callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(
        @"Tracking UIViewController.viewWillLayoutSubviews for view controller: %@", controller);
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(@"Not tracking UIViewController.viewWillLayoutSubviews because there "
                             @"is no active span.");
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            [self.tracker measureSpanWithDescription:@"viewWillLayoutSubviews"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];

            SentrySpanId *layoutSubViewId =
                [self.tracker startSpanWithName:@"layoutSubViews"
                                     nameSource:kSentryTransactionNameSourceComponent
                                      operation:SentrySpanOperationUiLoad
                                         origin:SentryTraceOriginAutoUIViewController];

            [self setLayoutSubviewSpanID:controller spanId:layoutSubViewId];
        };
        [self.tracker activateSpan:spanId duringBlock:duringBlock];

        // According to the Apple docs
        // (https://developer.apple.com/documentation/uikit/uiviewcontroller/1621510-viewwillappear),
        // viewWillAppear should be called for before the UIViewController is added to the view
        // hierarchy. There are some edge cases, though, when this doesn't happen, and we saw
        // customers' transactions also proofing this. Therefore, we must also report the
        // initial display here, as the customers' transactions had spans for
        // `viewWillLayoutSubviews`.
        [self reportInitialDisplayForController:controller];
    };

    [self limitOverride:@"viewWillLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewDidLayoutSubViews:(UIViewController *)controller
                           callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(
        @"Tracking UIViewController.viewDidLayoutSubviews for view controller: %@", controller);
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *_Nullable spanId = [self getSpanIdForViewController:controller];

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            SENTRY_LOG_DEBUG(@"Not tracking UIViewController.viewDidLayoutSubviews because there "
                             @"is no active span.");
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            SentrySpanId *layoutSubViewId =
                [self getLayoutSubviewSpanIdForViewController:controller];

            if (layoutSubViewId != nil) {
                SENTRY_LOG_DEBUG(@"Finishing layoutSubviews span id: %@, for view controller: %@",
                    layoutSubViewId.sentrySpanIdString, controller);
                [self.tracker finishSpan:layoutSubViewId];
            }

            [self.tracker measureSpanWithDescription:@"viewDidLayoutSubviews"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUiLoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];

            // We need to remove the spanId for layoutSubviews, as it is not needed anymore.
            [self setLayoutSubviewSpanID:controller spanId:nil];
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
    };

    [self limitOverride:@"viewDidLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

/**
 * When a custom UIViewController is a subclass of another custom UIViewController, the SDK
 * swizzles both functions, which would create one span for each UIViewController leading to
 * duplicate spans in the transaction. To fix this, we only allow one span per lifecycle method
 * at a time.
 */
- (void)limitOverride:(NSString *)description
               target:(UIViewController *)viewController
     callbackToOrigin:(void (^)(void))callbackToOrigin
                block:(void (^)(void))block

{
    NSMutableSet<NSString *> *spansInExecution =
        [self getSpansInExecutionSetForViewController:viewController];
    if (spansInExecution == nil) {
        spansInExecution = [[NSMutableSet alloc] init];
        [self setSpansInExecutionSetForViewController:viewController spansIds:spansInExecution];
    }

    if (![spansInExecution containsObject:description]) {
        [spansInExecution addObject:description];
        block();
        [spansInExecution removeObject:description];
    } else {
        SENTRY_LOG_DEBUG(@"Skipping tracking the method %@ for %@, cause we're already tracking it "
                         @"for a parent or child class.",
            description, viewController);
        callbackToOrigin();
    }
}

- (void)measurePerformance:(NSString *)description
                    target:(UIViewController *)viewController
          callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(@"Measuring performance for method: %@, for view controller: %@", description,
        viewController);
    SentrySpanId *spanId = [self getSpanIdForViewController:viewController];

    if (spanId == nil) {
        SENTRY_LOG_DEBUG(@"No longer tracking UIViewController %@", viewController);
        callbackToOrigin();
    } else {
        [self.tracker measureSpanWithDescription:description
                                      nameSource:kSentryTransactionNameSourceComponent
                                       operation:SentrySpanOperationUiLoad
                                          origin:SentryTraceOriginAutoUIViewController
                                    parentSpanId:spanId
                                         inBlock:callbackToOrigin];
    }
}

- (void)reportInitialDisplayForController:(NSObject *)controller
{
    SENTRY_LOG_DEBUG(@"Reporting initial display for controller: %@", controller);
    if (self.currentTTDTracker == nil) {
        SENTRY_LOG_DEBUG(
            @"Can't report initial display, no screen transaction being tracked right now.");
        return;
    }
    [self.currentTTDTracker reportInitialDisplay];
    SENTRY_LOG_DEBUG(@"Reported initial display for controller: %@", controller);
}

// - MARK: - Getter and Setter Helpers

- (SentryTimeToDisplayTracker *_Nullable)getTimeToDisplayTrackerForController:
    (UIViewController *)controller
{
    SENTRY_LOG_DEBUG(@"Getting time to display tracker for controller: %@", controller);
    return [self.ttdTrackers objectForKey:controller];
}

- (void)setTimeToDisplayTrackerForController:(UIViewController *)controller
                                  ttdTracker:(SentryTimeToDisplayTracker *)ttdTracker
{
    SENTRY_LOG_DEBUG(@"Setting time to display tracker for controller: %@, ttdTracker: %@",
        controller, ttdTracker);
    [self.ttdTrackers setObject:ttdTracker forKey:controller];
}

- (SentrySpanId *_Nullable)getSpanIdForViewController:(UIViewController *)controller
{
    SENTRY_LOG_DEBUG(@"Getting span id for controller: %@", controller);
    return [self.spanIds objectForKey:controller];
}

- (void)setSpanIdForViewController:(UIViewController *)controller
                            spanId:(SentrySpanId *_Nullable)spanId
{
    SENTRY_LOG_DEBUG(
        @"Setting span id for controller: %@, spanId: %@", controller, spanId.sentrySpanIdString);
    [self.spanIds setObject:spanId forKey:controller];
}

- (SentrySpanId *_Nullable)getLayoutSubviewSpanIdForViewController:
    (UIViewController *_Nonnull)controller
{
    SENTRY_LOG_DEBUG(@"Getting layout subview span id for controller: %@", controller);
    return [self.layoutSubviewSpanIds objectForKey:controller];
}

- (void)setLayoutSubviewSpanID:(UIViewController *_Nonnull)controller spanId:(SentrySpanId *)spanId
{
    SENTRY_LOG_DEBUG(@"Setting layout subview span id for controller: %@, spanId: %@", controller,
        spanId.sentrySpanIdString);
    [self.layoutSubviewSpanIds setObject:spanId forKey:controller];
}

- (NSMutableSet<NSString *> *_Nullable)getSpansInExecutionSetForViewController:
    (UIViewController *)viewController
{
    SENTRY_LOG_DEBUG(@"Getting spans in execution set for controller: %@", viewController);
    return [self.spansInExecution objectForKey:viewController];
}

- (void)setSpansInExecutionSetForViewController:(UIViewController *)viewController
                                       spansIds:(NSMutableSet<NSString *> *)spanIds
{
    SENTRY_LOG_DEBUG(
        @"Setting spans in execution set for controller: %@, spanIds: %@", viewController, spanIds);
    [self.spansInExecution setObject:spanIds forKey:viewController];
}

@end

#endif // SENTRY_HAS_UIKIT
