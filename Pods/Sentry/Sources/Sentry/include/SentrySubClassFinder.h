#import "SentryDefines.h"
#import "SentryObjCRuntimeWrapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper, SentryDefaultObjCRuntimeWrapper;

@interface SentrySubClassFinder : NSObject
SENTRY_NO_INIT

- (instancetype)initWithDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                   objcRuntimeWrapper:(id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
             swizzleClassNameExcludes:(NSSet<NSString *> *)swizzleClassNameExcludes;

#if SENTRY_HAS_UIKIT
/**
 * Fetch all subclasses of @c UIViewController from given objc Image on a background thread and then
 * act on them on the main thread. As there is no straightforward way to get all sub-classes in
 * Objective-C, the code first retrieves all classes from the Image, iterates over all classes, and
 * checks for every class if the parentClass is a @c UIViewController. Cause loading all classes can
 * take a few milliseconds, do this on a background thread.
 * @param imageName The objc Image (library) to get all subclasses for.
 * @param block The block to execute for each subclass. This block runs on the main thread.
 */
- (void)actOnSubclassesOfViewControllerInImage:(NSString *)imageName block:(void (^)(Class))block;
#endif // SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END
