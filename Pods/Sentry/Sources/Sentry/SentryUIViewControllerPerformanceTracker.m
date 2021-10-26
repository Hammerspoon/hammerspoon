#import "SentryUIViewControllerPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpanId.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerSanitizer.h"
#import <objc/runtime.h>

@interface
SentryUIViewControllerPerformanceTracker ()

@property (nonatomic, strong) SentryPerformanceTracker *tracker;

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
    }
    return self;
}

#if SENTRY_HAS_UIKIT

- (void)viewControllerLoadView:(UIViewController *)controller
              callbackToOrigin:(void (^)(void))callbackToOrigin
{
    [self limitOverride:@"loadView"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       [self createTransaction:controller];

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
        NSString *name = [SentryUIViewControllerSanitizer sanitizeViewControllerName:controller];
        spanId = [self.tracker startSpanWithName:name
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

        // Use the target itself to store the spanId to avoid using a global mapper.
        objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, spanId,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)viewControllerViewWillAppear:(UIViewController *)controller
                    callbackToOrigin:(void (^)(void))callbackToOrigin
{
    [self limitOverride:@"viewWillAppear"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SentrySpanId *spanId = objc_getAssociatedObject(
                           controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

                       if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
                           // We are no longer tracking this UIViewController, just call the base
                           // method.
                           callbackToOrigin();
                       } else {
                           [self.tracker pushActiveSpan:spanId];
                           [self.tracker
                               measureSpanWithDescription:@"viewWillAppear"
                                                operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                                  inBlock:callbackToOrigin];

                           SentrySpanId *viewAppearingId = [self.tracker
                               startSpanWithName:@"viewAppearing"
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

                           objc_setAssociatedObject(controller,
                               &SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID,
                               viewAppearingId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                           [self.tracker popActiveSpan];
                       }
                   }];
}

- (void)viewControllerViewDidAppear:(UIViewController *)controller
                   callbackToOrigin:(void (^)(void))callbackToOrigin
{
    [self finishTransaction:controller
                     status:kSentrySpanStatusUndefined
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
 * As stated above viewWillAppear doesn't need to be followed by a viewDidAppear. A viewWillAppear
 * can also be followed by a viewWillDisappear. Therefore, we finish the transaction in
 * viewWillDisappear, if it wasn't already finished in viewDidAppear.
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
        } else {
            SentrySpanId *viewAppearingId = objc_getAssociatedObject(
                controller, &SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID);
            if (viewAppearingId != nil) {
                [self.tracker finishSpan:viewAppearingId withStatus:status];
                objc_setAssociatedObject(controller,
                    &SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID, nil,
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }

            [self.tracker pushActiveSpan:spanId];
            [self.tracker measureSpanWithDescription:lifecycleMethod
                                           operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                             inBlock:callbackToOrigin];
            [self.tracker popActiveSpan]; // Pop ViewControllerSpan pushed at
                                          // viewWillAppear

            // If we are still tracking this UIViewController finish the transaction
            // and remove associated span id.
            [self.tracker finishSpan:spanId withStatus:status];
            objc_setAssociatedObject(controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    };

    [self limitOverride:lifecycleMethod
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:limitOverrideBlock];
}

- (void)viewControllerViewWillLayoutSubViews:(UIViewController *)controller
                            callbackToOrigin:(void (^)(void))callbackToOrigin
{
    [self limitOverride:@"viewWillLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SentrySpanId *spanId = objc_getAssociatedObject(
                           controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

                       if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
                           // We are no longer tracking this UIViewController, just call the base
                           // method.
                           callbackToOrigin();
                       } else {
                           [self.tracker pushActiveSpan:spanId];
                           [self.tracker
                               measureSpanWithDescription:@"viewWillLayoutSubviews"
                                                operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                                  inBlock:callbackToOrigin];

                           SentrySpanId *layoutSubViewId = [self.tracker
                               startSpanWithName:@"layoutSubViews"
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION];

                           objc_setAssociatedObject(controller,
                               &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID,
                               layoutSubViewId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

                           [self.tracker popActiveSpan];
                       }
                   }];
}

- (void)viewControllerViewDidLayoutSubViews:(UIViewController *)controller
                           callbackToOrigin:(void (^)(void))callbackToOrigin
{
    [self limitOverride:@"viewDidLayoutSubviews"
                  target:controller
        callbackToOrigin:callbackToOrigin
                   block:^{
                       SentrySpanId *spanId = objc_getAssociatedObject(
                           controller, &SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID);

                       if (spanId == nil || ![self.tracker isSpanAlive:spanId]) {
                           // We are no longer tracking this UIViewController, just call the base
                           // method.
                           callbackToOrigin();
                       } else {
                           SentrySpanId *layoutSubViewId = objc_getAssociatedObject(
                               controller, &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID);

                           if (layoutSubViewId != nil) {
                               [self.tracker finishSpan:layoutSubViewId];
                           }

                           [self.tracker pushActiveSpan:spanId];
                           [self.tracker
                               measureSpanWithDescription:@"viewDidLayoutSubviews"
                                                operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                                  inBlock:callbackToOrigin];

                           [self.tracker popActiveSpan]; // Pop ViewControllerSpan pushed at
                                                         // viewWillAppear
                           objc_setAssociatedObject(controller,
                               &SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID, nil,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                       }
                   }];
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
        // We are no longer tracking this UIViewController, just call the base method.
        callbackToOrigin();
    } else {
        [self.tracker measureSpanWithDescription:description
                                       operation:SENTRY_VIEWCONTROLLER_RENDERING_OPERATION
                                    parentSpanId:spanId
                                         inBlock:callbackToOrigin];
    }
}
#endif

@end
