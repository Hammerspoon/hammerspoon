#import "SentryDefines.h"
#import "SentryInternalCDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrash for testability.
 */
@interface SentryCrashWrapper : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

- (BOOL)crashedLastLaunch;

- (NSTimeInterval)durationFromCrashStateInitToLastCrash;

- (NSTimeInterval)activeDurationSinceLastCrash;

- (BOOL)isBeingTraced;

- (BOOL)isSimulatorBuild;

- (BOOL)isApplicationInForeground;

- (void)installAsyncHooks;

- (void)uninstallAsyncHooks;

- (NSDictionary *)systemInfo;

- (bytes)freeMemorySize;

- (bytes)appMemorySize;

- (bytes)freeStorageSize;

@end

NS_ASSUME_NONNULL_END
