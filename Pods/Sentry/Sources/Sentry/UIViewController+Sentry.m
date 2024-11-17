#import "UIViewController+Sentry.h"

#if SENTRY_HAS_UIKIT

@implementation SentryViewController

+ (NSArray<UIViewController *> *)descendantsOfViewController:(UIViewController *)viewController;
{

    // The implementation of UIViewController makes sure a parent can't be a child of his child.
    // Therefore, we can assume the parent child relationship is correct.

    NSMutableArray<UIViewController *> *allViewControllers = [NSMutableArray new];
    [allViewControllers addObject:viewController];

    NSMutableArray<UIViewController *> *toAdd =
        [NSMutableArray arrayWithArray:viewController.childViewControllers];

    while (toAdd.count > 0) {
        UIViewController *lastVC = [toAdd lastObject];
        [allViewControllers addObject:lastVC];
        [toAdd removeLastObject];
        [toAdd addObjectsFromArray:lastVC.childViewControllers];
    }

    return allViewControllers;
}

@end

#endif // SENTRY_HAS_UIKIT
