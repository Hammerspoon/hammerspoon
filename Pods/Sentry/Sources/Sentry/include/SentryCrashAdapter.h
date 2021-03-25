#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrash for testability.
 */
@interface SentryCrashAdapter : NSObject

- (BOOL)crashedLastLaunch;

- (NSTimeInterval)activeDurationSinceLastCrash;

- (BOOL)isBeingTraced;

@end

NS_ASSUME_NONNULL_END
