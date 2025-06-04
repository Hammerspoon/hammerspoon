#import "SentryDispatchFactory.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDispatchSourceWrapper.h"
#import "SentryInternalDefines.h"

@implementation SentryDispatchFactory

- (SentryDispatchQueueWrapper *)queueWithName:(const char *)name
                                   attributes:(dispatch_queue_attr_t)attributes
{
    return [[SentryDispatchQueueWrapper alloc] initWithName:name attributes:attributes];
}

- (SentryDispatchQueueWrapper *)createLowPriorityQueue:(const char *)name
                                      relativePriority:(int)relativePriority
{
    SENTRY_CASSERT(relativePriority <= 0 && relativePriority >= QOS_MIN_RELATIVE_PRIORITY,
        @"Relative priority must be between 0 and %d", QOS_MIN_RELATIVE_PRIORITY);
    // The QOS_CLASS_UTILITY is defined in `qos.h` and used by the `DISPATCH_QUEUE_PRIORITY_LOW`,
    // therefore it can be considered it a low priority queue
    // Reference: https://developer.apple.com/documentation/dispatch/dispatch_queue_priority_low
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, relativePriority);
    return [[SentryDispatchQueueWrapper alloc] initWithName:name attributes:attributes];
}

- (SentryDispatchSourceWrapper *)sourceWithInterval:(uint64_t)interval
                                             leeway:(uint64_t)leeway
                                          queueName:(const char *)queueName
                                         attributes:(dispatch_queue_attr_t)attributes
                                       eventHandler:(void (^)(void))eventHandler
{
    return [[SentryDispatchSourceWrapper alloc]
        initTimerWithInterval:interval
                       leeway:leeway
                        queue:[self queueWithName:queueName attributes:attributes]
                 eventHandler:eventHandler];
}

@end
