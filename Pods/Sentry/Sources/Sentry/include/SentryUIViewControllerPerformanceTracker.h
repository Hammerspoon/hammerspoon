#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentrySpan;
@class SentryInAppLogic;
@class SentryTimeToDisplayTracker;
@class UIViewController;
@class SentryTracer;
@class SentryPerformanceTracker;
@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

/**
 * Class responsible to track UI performance.
 * This class is intended to be used in a swizzled context.
 */
@interface SentryUIViewControllerPerformanceTracker : NSObject

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@property (nonatomic) BOOL alwaysWaitForFullDisplay;

SENTRY_NO_INIT

- (instancetype)initWithTracker:(SentryPerformanceTracker *)tracker
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

/**
 * Measures @c controller's @c loadView method.
 * This method starts a span that will be finished when @c viewControllerDidAppear:callBackToOrigin:
 * is called.
 * @param controller @c UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call  @c controller's original
 * @c loadView method.
 */
- (void)viewControllerLoadView:(UIViewController *)controller
              callbackToOrigin:(void (^)(void))callback;

/**
 * Measures @c controller's @c viewDidLoad method.
 * @param controller @c UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call  @c controller's original
 * @c viewDidLoad method.
 */
- (void)viewControllerViewDidLoad:(UIViewController *)controller
                 callbackToOrigin:(void (^)(void))callback;

/**
 * Measures @c controller's @c viewWillAppear: method.
 * @param controller @c UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call  @c controller's original
 * @c viewWillAppear: method.
 */
- (void)viewControllerViewWillAppear:(UIViewController *)controller
                    callbackToOrigin:(void (^)(void))callback;

- (void)viewControllerViewWillDisappear:(UIViewController *)controller
                       callbackToOrigin:(void (^)(void))callbackToOrigin;

/**
 * Measures @c controller's @c viewDidAppear: method.
 * This method also finishes the span created at
 * @c viewControllerLoadView:callbackToOrigin: allowing
 * the transaction to be send to Sentry when all spans are finished.
 * @param controller @c UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call  @c controller's original
 * @c viewDidAppear: method.
 */
- (void)viewControllerViewDidAppear:(UIViewController *)controller
                   callbackToOrigin:(void (^)(void))callback;

/**
 * Measures @c controller's @c viewWillLayoutSubViews method.
 * This method starts a span that is only finish when
 * @c viewControllerViewDidLayoutSubViews:callbackToOrigin: is called.
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call @c controller's original
 * @c viewWillLayoutSubViews method.
 */
- (void)viewControllerViewWillLayoutSubViews:(UIViewController *)controller
                            callbackToOrigin:(void (^)(void))callback;

/**
 * Measures @c controller's @c viewDidLayoutSubViews method.
 * This method also finished the span created at
 * @c viewControllerViewWillLayoutSubViews:callbackToOrigin:
 * that measures all work done in views between this two methods.
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call  @c controller's original
 * @c viewDidLayoutSubViews method.
 */
- (void)viewControllerViewDidLayoutSubViews:(UIViewController *)controller
                           callbackToOrigin:(void (^)(void))callback;

- (void)reportFullyDisplayed;

- (nullable SentryTimeToDisplayTracker *)startTimeToDisplayTrackerForScreen:(NSString *)screenName
                                                         waitForFullDisplay:(BOOL)waitForFullDisplay
                                                                     tracer:(SentryTracer *)tracer;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
