#import "SentryDefines.h"
#import "SentryInternalCDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryScope;

/** A wrapper around SentryCrash for testability.
 */
@interface SentryCrashWrapper : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

- (void)startBinaryImageCache;

- (void)stopBinaryImageCache;

- (BOOL)crashedLastLaunch;

- (NSTimeInterval)durationFromCrashStateInitToLastCrash;

- (NSTimeInterval)activeDurationSinceLastCrash;

- (BOOL)isBeingTraced;

- (BOOL)isSimulatorBuild;

- (BOOL)isApplicationInForeground;

- (NSDictionary *)systemInfo;

- (bytes)freeMemorySize;

- (bytes)appMemorySize;

- (void)enrichScope:(SentryScope *)scope;

@end

NS_ASSUME_NONNULL_END
