#import "SentryDefines.h"
#import "SentryFileIOTracker.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

@interface SentryNSFileManagerSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly) SentryNSFileManagerSwizzling *shared;

- (void)startWithOptions:(SentryOptions *)options tracker:(SentryFileIOTracker *)tracker;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
