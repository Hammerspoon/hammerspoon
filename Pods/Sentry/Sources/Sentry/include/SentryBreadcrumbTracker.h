#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySwizzleWrapper;

@interface SentryBreadcrumbTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper;

- (void)start;
- (void)startSwizzle;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
