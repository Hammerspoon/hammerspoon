#import <Foundation/Foundation.h>

@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around a @c dispatch_source_t that can be subclassed for mocking in tests.
 */
@interface SentryDispatchSourceWrapper : NSObject

- (instancetype)initTimerWithInterval:(uint64_t)interval
                               leeway:(uint64_t)leeway
                                queue:(SentryDispatchQueueWrapper *)queueWrapper
                         eventHandler:(void (^)(void))eventHandler;

- (void)cancel;

#if SENTRY_TEST || SENTRY_TEST_CI
- (dispatch_source_t)source;
- (SentryDispatchQueueWrapper *)queue;
#endif // SENTRY_TEST || SENTRY_TEST_CI

@end

NS_ASSUME_NONNULL_END
