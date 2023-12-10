#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface
UIView (Sentry)

- (NSString *)sentry_recursiveViewHierarchyDescription;

@end

NS_ASSUME_NONNULL_END

#endif
