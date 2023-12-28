#import "SentryDispatchSourceWrapper.h"
#import "SentryDispatchQueueWrapper.h"

@implementation SentryDispatchSourceWrapper {
    SentryDispatchQueueWrapper *_queueWrapper;
    dispatch_source_t _source;
}

- (instancetype)initTimerWithInterval:(uint64_t)interval
                               leeway:(uint64_t)leeway
                                queue:(SentryDispatchQueueWrapper *)queueWrapper
                         eventHandler:(void (^)(void))eventHandler
{
    if (self = [super init]) {
        _queueWrapper = queueWrapper;
        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queueWrapper.queue);
        dispatch_source_set_event_handler(_source, eventHandler);
        dispatch_source_set_timer(_source, dispatch_time(DISPATCH_TIME_NOW, 0), interval, leeway);
        dispatch_resume(_source);
    }
    return self;
}

- (void)cancel
{
    dispatch_cancel(_source);
}

@end
