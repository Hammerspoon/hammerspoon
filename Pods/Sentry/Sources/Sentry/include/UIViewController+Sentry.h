#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryViewController : NSObject

/**
 * An array of view controllers that are descendants, meaning children, grandchildren, ... , of the
 * current view controller.
 */
+ (NSArray<UIViewController *> *)descendantsOfViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
