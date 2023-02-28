#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around NSThread functions for testability.
 */
@interface SentryThreadWrapper : NSObject

- (void)sleepForTimeInterval:(NSTimeInterval)timeInterval;

- (void)threadStarted:(NSUUID *)threadID;

- (void)threadFinished:(NSUUID *)threadID;

@end

NS_ASSUME_NONNULL_END
