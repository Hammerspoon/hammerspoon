#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around NSThread functions for testability.
 */
@interface SentryThreadWrapper : NSObject

- (void)sleepForTimeInterval:(NSTimeInterval)timeInterval;

- (void)threadStarted:(NSUUID *)threadID;

- (void)threadFinished:(NSUUID *)threadID;

/**
 * Ensure a block runs on the main thread. If called from the main thread, execute the block
 * synchronously. If called from a non-main thread, then dispatch the block to the main queue
 * asynchronously.
 * @warning The block will not execute until the main queue is freed by the caller. Try to return up
 * the call stack as soon as possible after calling this method if you need the block to execute in
 * a timely manner.
 */
+ (void)onMainThread:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
