#import "SentryDispatchQueueWrapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDispatchQueueWrapper {
    // Don't use a normal property because on RN a user got a warning "Property with 'retain (or
    // strong)' attribute must be of object type". A dispatch queue is since iOS 6.0 an NSObject so
    // it should work with strong, but nevertheless, we use an instance variable to fix this
    // warning.
    dispatch_queue_t queue;
}

- (instancetype)init
{
    // DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL is requires iOS 10. Since we are targeting
    // iOS 9 we need to manually add the autoreleasepool.
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self = [self initWithName:"sentry-default" attributes:attributes];
    return self;
}

- (instancetype)initWithName:(const char *)name attributes:(dispatch_queue_attr_t)attributes;
{
    if (self = [super init]) {
        queue = dispatch_queue_create(name, attributes);
    }
    return self;
}

- (void)dispatchAsyncWithBlock:(void (^)(void))block
{
    dispatch_async(queue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchAsyncOnMainQueue:(void (^)(void))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

- (void)dispatchAfter:(NSTimeInterval)interval block:(dispatch_block_t)block
{
    dispatch_time_t delta = (int64_t)(interval * NSEC_PER_SEC);
    dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, delta);
    dispatch_after(when, queue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchCancel:(dispatch_block_t)block
{
    dispatch_block_cancel(block);
}

- (void)dispatchOnce:(dispatch_once_t *)predicate block:(void (^)(void))block
{
    dispatch_once(predicate, block);
}

@end

NS_ASSUME_NONNULL_END
