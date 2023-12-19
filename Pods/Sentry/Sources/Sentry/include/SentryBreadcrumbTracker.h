#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryBreadcrumbDelegate;

@interface SentryBreadcrumbTracker : NSObject

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate;
#if SENTRY_HAS_UIKIT
- (void)startSwizzle;
#endif // SENTRY_HAS_UIKIT
- (void)stop;

@end

NS_ASSUME_NONNULL_END
