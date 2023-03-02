#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_VIEWCONTROLLER_RENDERING_OPERATION = @"ui.load";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID
    = @"SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID";

static NSString *const SENTRY_UI_PERFORMANCE_TRACKER_SPANS_IN_EXECUTION_SET
    = @"SENTRY_UI_PERFORMANCE_TRACKER_SPANS_IN_EXECUTION_SET";

/**
 * Class responsible to track UI performance.
 * This class is intended to be used in a swizzled context.
 */
@interface SentryUIViewControllerPerformanceTracker : NSObject
#if SENTRY_HAS_UIKIT
@property (nonatomic, readonly, class) SentryUIViewControllerPerformanceTracker *shared;

/**
 * Measures viewController`s loadView method.
 * This method starts a span that will be finished when
 * viewControllerDidAppear:callBackToOrigin: is called.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * LoadView method.
 */
- (void)viewControllerLoadView:(UIViewController *)controller
              callbackToOrigin:(void (^)(void))callback;

/**
 * Measures viewController`s viewDidLoad method.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewDidLoad method.
 */
- (void)viewControllerViewDidLoad:(UIViewController *)controller
                 callbackToOrigin:(void (^)(void))callback;

/**
 * Measures viewController`s viewWillAppear: method.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewWillAppear: method.
 */
- (void)viewControllerViewWillAppear:(UIViewController *)controller
                    callbackToOrigin:(void (^)(void))callback;

- (void)viewControllerViewWillDisappear:(UIViewController *)controller
                       callbackToOrigin:(void (^)(void))callbackToOrigin;

/**
 * Measures viewController`s viewDidAppear: method.
 * This method also finishes the span created at
 * viewControllerLoadView:callbackToOrigin: allowing
 * the transaction to be send to Sentry when all spans are finished.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewDidAppear: method.
 */
- (void)viewControllerViewDidAppear:(UIViewController *)controller
                   callbackToOrigin:(void (^)(void))callback;

/**
 * Measures viewController`s viewWillLayoutSubViews method.
 * This method starts a span that is only finish when
 * viewControllerViewDidLayoutSubViews:callbackToOrigin: is called.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewWillLayoutSubViews method.
 */
- (void)viewControllerViewWillLayoutSubViews:(UIViewController *)controller
                            callbackToOrigin:(void (^)(void))callback;

/**
 * Measures viewController`s viewDidLayoutSubViews method.
 * This method also finished the span created at
 * viewControllerViewWillLayoutSubViews:callbackToOrigin:
 * that measures all work done in views between this two methods.
 *
 * @param controller UIViewController to be measured
 * @param callback A callback that indicates the swizzler to call the original view controller
 * viewDidLayoutSubViews method.
 */
- (void)viewControllerViewDidLayoutSubViews:(UIViewController *)controller
                           callbackToOrigin:(void (^)(void))callback;
#endif
@end

NS_ASSUME_NONNULL_END
