#import "SentryInternalDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryBreadcrumbDelegate <NSObject>

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

@end

NS_ASSUME_NONNULL_END
