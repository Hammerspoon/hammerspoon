#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT
#    define SentryDidBecomeActiveNotification UIApplicationDidBecomeActiveNotification
#    define SentryWillResignActiveNotification UIApplicationWillResignActiveNotification
#    define SentryWillTerminateNotification UIApplicationWillTerminateNotification
#elif SENTRY_TARGET_MACOS_HAS_UI
#    define SentryDidBecomeActiveNotification NSApplicationDidBecomeActiveNotification
#    define SentryWillResignActiveNotification NSApplicationWillResignActiveNotification
#    define SentryWillTerminateNotification NSApplicationWillTerminateNotification
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around @c NSNotificationCenter functions for testability.
 * @discussion Testing with @c NSNotificationCenter in CI leads to flaky tests for some classes.
 * Therefore, we can use a wrapper around @c NSNotificationCenter to not depend on it. Instead, we
 * call the methods
 * @c NSNotificationCenter would call with Dynamic and ensure that sut properly subscribes to
 * @c NSNotificationCenter.
 */
@interface SentryNSNotificationCenterWrapper : NSObject

- (void)addObserver:(NSObject *)observer
           selector:(SEL)aSelector
               name:(NSNotificationName)aName
             object:(nullable id)anObject;

- (void)addObserver:(NSObject *)observer selector:(SEL)aSelector name:(NSNotificationName)aName;

/**
 * @note Per NSNotificationCenter's docs: The return value is retained by the system, and should be
 * held onto by the caller in order to remove the observer with removeObserver: later, to stop
 * observation.
 */
- (id<NSObject>)addObserverForName:(nullable NSNotificationName)name
                            object:(nullable id)obj
                             queue:(nullable NSOperationQueue *)queue
                        usingBlock:(void (^)(NSNotification *notification))block;

- (void)removeObserver:(id<NSObject>)observer
                  name:(NSNotificationName)aName
                object:(nullable id)anObject;

- (void)removeObserver:(id<NSObject>)observer name:(NSNotificationName)aName;

- (void)removeObserver:(id<NSObject>)observer;

- (void)postNotification:(NSNotification *)notification;

NS_ASSUME_NONNULL_END

@end
