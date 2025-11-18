#import <Foundation/Foundation.h>

@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryDispatchQueueProviderProtocol <NSObject>

/**
 * Generate a new @c SentryDispatchQueueWrapper .
 */
- (SentryDispatchQueueWrapper *)queueWithName:(const char *)name
                                   attributes:(dispatch_queue_attr_t)attributes;

/**
 * Creates a utility QoS queue with the given name and relative priority, wrapped in a @c
 * SentryDispatchQueueWrapper.
 *
 * @note This method is only a factory method and does not keep a reference to the created queue.
 *
 * @param name The name of the queue.
 * @param relativePriority A negative offset from the maximum supported scheduler priority for the
 * given quality-of-service class. This value must be less than 0 and greater than or equal to @c
 * QOS_MIN_RELATIVE_PRIORITY, otherwise throws an assertion and returns an unspecified
 * quality-of-service.
 * @return Unretained reference to the created queue.
 */
- (SentryDispatchQueueWrapper *)createUtilityQueue:(const char *)name
                                  relativePriority:(int)relativePriority;

@end

NS_ASSUME_NONNULL_END
