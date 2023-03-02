#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around DispatchQueue functions for testability.
 */
@interface SentryDispatchQueueWrapper : NSObject

- (instancetype)initWithName:(const char *)name attributes:(dispatch_queue_attr_t)attributes;

- (void)dispatchAsyncWithBlock:(void (^)(void))block;

- (void)dispatchOnMainQueue:(void (^)(void))block;

- (void)dispatchOnce:(dispatch_once_t *)predicate block:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
