#import "SentryHub.h"

@class SentryId, SentryScope;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHub (Private)

- (void)captureCrashEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
