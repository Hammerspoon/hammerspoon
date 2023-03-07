#import "UIViewController+Sentry.h"

#if SENTRY_HAS_UIKIT

@implementation
UIViewController (Sentry)

- (NSArray<UIViewController *> *)sentry_descendantViewControllers
{

    // The implementation of UIViewController makes sure a parent can't be a child of his child.
    // Therefore, we can assume the parent child relationship is correct.

    NSMutableArray<UIViewController *> *allViewControllers = [NSMutableArray new];
    [allViewControllers addObject:self];

    NSMutableArray<UIViewController *> *toAdd =
        [NSMutableArray arrayWithArray:self.childViewControllers];

    while (toAdd.count > 0) {
        UIViewController *viewController = [toAdd lastObject];
        [allViewControllers addObject:viewController];
        [toAdd removeLastObject];
        [toAdd addObjectsFromArray:viewController.childViewControllers];
    }

    return allViewControllers;
}

@end

#endif
