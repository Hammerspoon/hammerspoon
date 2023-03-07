#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface
UIViewController (Sentry)

/**
 * An array of view controllers that are descendants, meaning children, grandchildren, ... , of the
 * current view controller.
 */
@property (nonatomic, readonly, strong)
    NSArray<UIViewController *> *sentry_descendantViewControllers;

@end

NS_ASSUME_NONNULL_END

#endif
