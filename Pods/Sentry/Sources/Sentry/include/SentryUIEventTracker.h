#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;
@protocol SentryUIEventTrackerMode;

@interface SentryUIEventTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithMode:(id<SentryUIEventTrackerMode>)mode;

- (void)start;
- (void)stop;

+ (BOOL)isUIEventOperation:(NSString *)operation;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
