#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrash for testability.
 */
@interface SentryCrashAdapter : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

- (BOOL)crashedLastLaunch;

- (NSTimeInterval)activeDurationSinceLastCrash;

- (BOOL)isBeingTraced;

- (void)installAsyncHooks;

- (void)deactivateAsyncHooks;

@end

NS_ASSUME_NONNULL_END
