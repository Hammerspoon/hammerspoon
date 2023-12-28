#import "SentryDefines.h"

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

#if SENTRY_HAS_UIKIT || SENTRY_TARGET_MACOS
@property (nonatomic, readonly, copy, class) NSNotificationName didBecomeActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willResignActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willTerminateNotificationName;
#endif

- (void)addObserver:(id)observer
           selector:(SEL)aSelector
               name:(NSNotificationName)aName
             object:(nullable id)anObject;

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(nullable id)anObject;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer;

- (void)postNotificationName:(NSNotificationName)aName object:(nullable id)anObject;

NS_ASSUME_NONNULL_END

@end
