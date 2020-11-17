#import "SentrySDK.h"

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (Private)

+ (void)captureCrashEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
