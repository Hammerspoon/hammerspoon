#import "SentryDispatchQueueWrapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDispatchQueueWrapper ()

@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation SentryDispatchQueueWrapper

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
        self.queue = dispatch_queue_create(name, attributes);
    }
    return self;
}

- (void)dispatchAsyncWithBlock:(void (^)(void))block
{
    dispatch_async(self.queue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchOnce:(dispatch_once_t *)predicate block:(void (^)(void))block
{
    dispatch_once(predicate, block);
}
@end

NS_ASSUME_NONNULL_END
