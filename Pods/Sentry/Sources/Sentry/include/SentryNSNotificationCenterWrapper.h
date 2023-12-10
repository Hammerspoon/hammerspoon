#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around NSNotificationCenter functions for testability.
 *
 * Testing with NSNotificationCenter in CI leads to flaky tests for some classes. Therefore, we can
 * use a wrapper around NSNotificationCenter to not depend on it. Instead, we call the methods
 * NSNotificationCenter would call with Dynamic and ensure that sut properly subscribes to
 * NSNotificationCenter.
 */
@interface SentryNSNotificationCenterWrapper : NSObject

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
@property (nonatomic, readonly, copy, class) NSNotificationName didBecomeActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willResignActiveNotificationName;
@property (nonatomic, readonly, copy, class) NSNotificationName willTerminateNotificationName;
#endif

- (void)addObserver:(id)observer
           selector:(SEL)aSelector
               name:(NSNotificationName)aName
             object:(id)anObject;

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(id)anObject;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName;

- (void)removeObserver:(id)observer;

- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject;

NS_ASSUME_NONNULL_END

@end
