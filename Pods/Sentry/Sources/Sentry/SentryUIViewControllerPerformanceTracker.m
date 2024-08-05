#import "SentryUIViewControllerPerformanceTracker.h"

#if SENTRY_HAS_UIKIT

#    import "SentryDependencyContainer.h"
#    import "SentryHub.h"
#    import "SentryLog.h"
#    import "SentryOptions.h"
#    import "SentryPerformanceTracker.h"
#    import "SentrySDK+Private.h"
#    import "SentrySpanId.h"
#    import "SentrySwift.h"
#    import "SentryTimeToDisplayTracker.h"
#    import "SentryTraceOrigins.h"
#    import "SentryTracer.h"
#    import <SentryInAppLogic.h>
#    import <SentrySpanOperations.h>
#    import <UIKit/UIKit.h>
#    import <objc/runtime.h>

@interface
SentryUIViewControllerPerformanceTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;
@property (nullable, nonatomic, weak) SentryTimeToDisplayTracker *currentTTDTracker;
@property (nonatomic, strong, readonly) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

@implementation SentryUIViewControllerPerformanceTracker

+ (instancetype)shared
{
    static SentryUIViewControllerPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.tracker = SentryPerformanceTracker.shared;

        SentryOptions *options = [SentrySDK options];
        self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                            inAppExcludes:options.inAppExcludes];

        _enableWaitForFullDisplay = NO;
        _dispatchQueueWrapper = SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
    }
    return self;
}

- (SentrySpan *)viewControllerPerformanceSpan:(UIViewController *)controller
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);
    return [self.tracker getSpan:spanId];
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

    [self limitOverride:@"loadView"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SENTRY_LOG_DEBUG(@"Tracking loadView");
                       [self createTransaction:controller];
                       [self createTimeToDisplay:controller];
                       [self measurePerformance:@"loadView"
                                         target:controller
                               callbackToOrigin:callbackToOrigin];
                   }];
}

- (void)viewControllerViewDidLoad:(UIViewController *)controller
                 callbackToOrigin:(void (^)(void))callbackToOrigin
{
    [self limitOverride:@"viewDidLoad"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SENTRY_LOG_DEBUG(@"Tracking viewDidLoad");
                       [self createTransaction:controller];
                       [self measurePerformance:@"viewDidLoad"
                                         target:controller
                               callbackToOrigin:callbackToOrigin];
                   }];
}

- (void)createTransaction:(UIViewController *)controller
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    // If the user manually calls loadView outside the lifecycle we don't start a new transaction
    // and override the previous id stored.
    if (spanId == nil) {
        NSString *name = [SwiftDescriptor getObjectClassName:controller];
        spanId = [self.tracker startSpanWithName:name
                                      nameSource:kSentryTransactionNameSourceComponent
                                       operation:SentrySpanOperationUILoad
                                          origin:SentryTraceOriginAutoUIViewController];
        SENTRY_LOG_DEBUG(@"Started span with id %@ to track view controller %@.",
            spanId.sentrySpanIdString, name);

        // Use the target itself to store the spanId to avoid using a global mapper.
        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // If there is no active span in the queue push this transaction
        // to serve as an umbrella transaction that will capture every span
        // happening while the transaction is active.
        if (self.tracker.activeSpanId == nil) {
            [self.tracker pushActiveSpan:spanId];
        }
    }
}

- (void)createTimeToDisplay:(UIViewController *)controller
{
    SentrySpan *vcSpan = [self viewControllerPerformanceSpan:controller];

    if (![vcSpan isKindOfClass:[SentryTracer self]]) {
        // Since TTID and TTFD are meant to the whole screen
        // we will not track child view controllers
        return;
    }

    if (objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_TTD_TRACKER)) {
        // Already tracking time to display, not creating a new tracker.
        // This may happen if user manually call `loadView` from a view controller more than once.
        return;
    }

    SentryTimeToDisplayTracker *ttdTracker =
        [[SentryTimeToDisplayTracker alloc] initForController:controller
                                           waitForFullDisplay:self.enableWaitForFullDisplay
                                         dispatchQueueWrapper:_dispatchQueueWrapper];

    objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_TTD_TRACKER, ttdTracker,
        OBJC_ASSOCIATION_ASSIGN);
    [ttdTracker startForTracer:(SentryTracer *)vcSpan];

    self.currentTTDTracker = ttdTracker;
}

- (void)reportFullyDisplayed
{
    [self.currentTTDTracker reportFullyDisplayed];
}

- (void)viewControllerViewWillAppear:(UIViewController *)controller
                    callbackToOrigin:(void (^)(void))callbackToOrigin
{
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            SENTRY_LOG_DEBUG(@"Tracking UIViewController.viewWillAppear");
            [self.tracker measureSpanWithDescription:@"viewWillAppear"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUILoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];

        SentryTimeToDisplayTracker *ttdTracker
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_TTD_TRACKER);
        [ttdTracker reportInitialDisplay];
    };

    [self limitOverride:@"viewWillAppear"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewDidAppear:(UIViewController *)controller
                   callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SENTRY_LOG_DEBUG(@"Tracking UIViewController.viewDidAppear");
    [self finishTransaction:controller
                     status:kSentrySpanStatusOk
            lifecycleMethod:@"viewDidAppear"
           callbackToOrigin:callbackToOrigin];
}

/**
 * According to the apple docs, see
 * https://developer.apple.com/documentation/uikit/uiviewcontroller: Not all ‘will’ callback methods
 * are paired with only a ‘did’ callback method. You need to ensure that if you start a process in a
 * ‘will’ callback method, you end the process in both the corresponding ‘did’ and the opposite
 * ‘will’ callback method.
 *
 * As stated above @c viewWillAppear doesn't need to be followed by a @c viewDidAppear. A
 * @c viewWillAppear can also be followed by a @c viewWillDisappear. Therefore, we finish the
 * transaction in
 * @c viewWillDisappear, if it wasn't already finished in @c viewDidAppear.
 */
- (void)viewControllerViewWillDisappear:(UIViewController *)controller
                       callbackToOrigin:(void (^)(void))callbackToOrigin
{

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
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            [self.tracker measureSpanWithDescription:lifecycleMethod
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUILoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
        id<SentrySpan> vcSpan = [self.tracker getSpan:spanId];
        // If the current controller span has no parent,
        // it means it is the root transaction and need to be pop from the queue.
        if (vcSpan.parentSpanId == nil) {
            [self.tracker popActiveSpan];
        }

        // If we are still tracking this UIViewController finish the transaction
        // and remove associated span id.
        [self.tracker finishSpan:spanId withStatus:status];

        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    };

    [self limitOverride:lifecycleMethod
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewWillLayoutSubViews:(UIViewController *)controller
                            callbackToOrigin:(void (^)(void))callbackToOrigin
{
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            [self.tracker measureSpanWithDescription:@"viewWillLayoutSubviews"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUILoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];

            SentrySpanId *layoutSubViewId =
                [self.tracker startSpanWithName:@"layoutSubViews"
                                     nameSource:kSentryTransactionNameSourceComponent
                                      operation:SentrySpanOperationUILoad
                                         origin:SentryTraceOriginAutoUIViewController];

            objc_setAssociatedObject(controller,
                &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID, layoutSubViewId,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        };
        [self.tracker activateSpan:spanId duringBlock:duringBlock];
    };

    [self limitOverride:@"viewWillLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewDidLayoutSubViews:(UIViewController *)controller
                           callbackToOrigin:(void (^)(void))callbackToOrigin
{
    void (^limitOverrideBlock)(void) = ^{
        SentrySpanId *spanId
            = objc_getAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

        if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
            // We are no longer tracking this UIViewController, just call the base
            // method.
            callbackToOrigin();
            return;
        }

        void (^duringBlock)(void) = ^{
            SentrySpanId *layoutSubViewId = objc_getAssociatedObject(
                controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID);

            if (layoutSubViewId != nil) {
                [self.tracker finishSpan:layoutSubViewId];
            }

            [self.tracker measureSpanWithDescription:@"viewDidLayoutSubviews"
                                          nameSource:kSentryTransactionNameSourceComponent
                                           operation:SentrySpanOperationUILoad
                                              origin:SentryTraceOriginAutoUIViewController
                                             inBlock:callbackToOrigin];

            objc_setAssociatedObject(controller,
                &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID, nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        };

        [self.tracker activateSpan:spanId duringBlock:duringBlock];
    };

    [self limitOverride:@"viewDidLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

/**
 * When a custom UIViewController is a subclass of another custom UIViewController, the SDK swizzles
 * both functions, which would create one span for each UIViewController leading to duplicate spans
 * in the transaction. To fix this, we only allow one span per lifecycle method at a time.
 */
- (void)limitOverride:(NSString *)description
               target:(UIViewController *)viewController
     callbackToOrigin:(void (^)(void))callbackToOrigin
                block:(void (^)(void))block

{
    NSMutableSet<NSString *> *spansInExecution;

    spansInExecution = objc_getAssociatedObject(
        viewController, &SENTRY_UI_PERFORMANCE_TRACKER_SPANS_IN_EXECUTION_SET);
    if (spansInExecution == nil) {
        spansInExecution = [[NSMutableSet alloc] init];
        objc_setAssociatedObject(viewController,
            &SENTRY_UI_PERFORMANCE_TRACKER_SPANS_IN_EXECUTION_SET, spansInExecution,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (![spansInExecution containsObject:description]) {
        [spansInExecution addObject:description];
        block();
        [spansInExecution removeObject:description];
    } else {
        callbackToOrigin();
    }
}

- (void)measurePerformance:(NSString *)description
                    target:(UIViewController *)viewController
          callbackToOrigin:(void (^)(void))callbackToOrigin
{
    SentrySpanId *spanId
        = objc_getAssociatedObject(viewController, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

    if (spanId == nil) {
        SENTRY_LOG_DEBUG(@"No longer tracking UIViewController %@", viewController);
        callbackToOrigin();
    } else {
        [self.tracker measureSpanWithDescription:description
                                      nameSource:kSentryTransactionNameSourceComponent
                                       operation:SentrySpanOperationUILoad
                                          origin:SentryTraceOriginAutoUIViewController
                                    parentSpanId:spanId
                                         inBlock:callbackToOrigin];
    }
}

@end

#endif // SENTRY_HAS_UIKIT
