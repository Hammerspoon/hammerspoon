#import <Foundation/Foundation.h>

@class SentryDispatchSourceWrapper;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryDispatchSourceProviderProtocol <NSObject>

/**
 * Generate a @c dispatch_source_t by internally vending the required @c SentryDispatchQueueWrapper.
 */
- (SentryDispatchSourceWrapper *)sourceWithInterval:(uint64_t)interval
                                             leeway:(uint64_t)leeway
                                          queueName:(const char *)queueName
                                         attributes:(dispatch_queue_attr_t)attributes
                                       eventHandler:(void (^)(void))eventHandler;
@end

NS_ASSUME_NONNULL_END
