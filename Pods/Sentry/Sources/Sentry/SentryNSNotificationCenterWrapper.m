#import "SentryNSNotificationCenterWrapper.h"

#import "SentryDefines.h"

#if SENTRY_TARGET_MACOS_HAS_UI
#    import <Cocoa/Cocoa.h>
#endif

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@implementation SentryNSNotificationCenterWrapper

- (void)addObserver:(NSObject *)observer
           selector:(SEL)aSelector
               name:(NSNotificationName)aName
             object:(nullable id)anObject
{
    [NSNotificationCenter.defaultCenter addObserver:observer
                                           selector:aSelector
                                               name:aName
                                             object:anObject];
}

- (void)addObserver:(NSObject *)observer selector:(SEL)aSelector name:(NSNotificationName)aName
{
    [NSNotificationCenter.defaultCenter addObserver:observer
                                           selector:aSelector
                                               name:aName
                                             object:nil];
}

- (id<NSObject>)addObserverForName:(nullable NSNotificationName)name
                            object:(nullable id)obj
                             queue:(nullable NSOperationQueue *)queue
                        usingBlock:(void (^)(NSNotification *notification))block
{
    return [NSNotificationCenter.defaultCenter addObserverForName:name
                                                           object:obj
                                                            queue:queue
                                                       usingBlock:block];
}

- (void)removeObserver:(NSObject *)observer name:(NSNotificationName)aName
{
    [NSNotificationCenter.defaultCenter removeObserver:observer name:aName object:nil];
}

- (void)removeObserver:(NSObject *)observer
                  name:(NSNotificationName)aName
                object:(nullable id)anObject
{
    [NSNotificationCenter.defaultCenter removeObserver:observer name:aName object:anObject];
}

- (void)removeObserver:(id<NSObject>)observer
{
    [NSNotificationCenter.defaultCenter removeObserver:observer];
}

- (void)postNotification:(NSNotification *)notification
{
    [NSNotificationCenter.defaultCenter postNotification:notification];
}

@end

NS_ASSUME_NONNULL_END
