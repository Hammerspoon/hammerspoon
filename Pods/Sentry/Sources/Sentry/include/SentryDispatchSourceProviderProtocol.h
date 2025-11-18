#import "SentrySwift.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryDispatchSourceProviderProtocol <NSObject>

/**
 * Generate a @c dispatch_source_t by internally vending the required @c SentryDispatchQueueWrapper.
 */
- (SentryDispatchSourceWrapper *)sourceWithInterval:(NSInteger)interval
                                             leeway:(NSInteger)leeway
                                          queueName:(const char *)queueName
                                         attributes:(dispatch_queue_attr_t)attributes
                                       eventHandler:(void (^)(void))eventHandler;
@end

NS_ASSUME_NONNULL_END
