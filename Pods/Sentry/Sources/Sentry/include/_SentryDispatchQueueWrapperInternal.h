#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around DispatchQueue functions for testability.
 * This should not be used directly, instead the  Swift version in
 * SentryDispatchQueueWrapper should be used to ensure compatibility
 * with Swift code.
 */
@interface _SentryDispatchQueueWrapperInternal : NSObject

@property (strong, nonatomic) dispatch_queue_t queue;

- (instancetype)initWithName:(const char *)name
                  attributes:(nullable dispatch_queue_attr_t)attributes;

- (void)dispatchAsyncWithBlock:(void (^)(void))block;

- (void)dispatchSync:(void (^)(void))block;

- (void)dispatchAsyncOnMainQueue:(void (^)(void))block
    NS_SWIFT_NAME(dispatchAsyncOnMainQueue(block:));

- (void)dispatchSyncOnMainQueue:(void (^)(void))block
    NS_SWIFT_NAME(dispatchSyncOnMainQueue(block:));

- (BOOL)dispatchSyncOnMainQueue:(void (^)(void))block timeout:(NSTimeInterval)timeout;

- (void)dispatchAfter:(NSTimeInterval)interval block:(void (^)(void))block;

- (void)dispatchOnce:(dispatch_once_t *)predicate block:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
