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
    self = [super init];
    if (self) {
        // DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL is requires iOS 10. Since we are targeting
        // iOS 9 we need to manually add the autoreleasepool.
        self.queue = dispatch_queue_create("sentry-dispatch", DISPATCH_QUEUE_SERIAL);
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
