#import "SentryDefines.h"
#import "SentryObjCRuntimeWrapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper, SentryDefaultObjCRuntimeWrapper;

@interface SentrySubClassFinder : NSObject
SENTRY_NO_INIT

- (instancetype)initWithDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                   objcRuntimeWrapper:(id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper;

/**
 * Fetch all subclasses of parentClass on a background thread and then act on them on the main
 * thread. As there is no straightforward way to get all sub-classes in Objective-C, the code first
 * retrieves all classes in the runtime, iterates over all classes, and checks for every class if
 * the parentClass is a parent. Cause loading all classes can take a few milliseconds, do this on a
 * background thread.
 *
 * @param parentClass The class to get all subclasses for.
 * @param block The block to execute for each subclass. This block runs on the main thread.
 */
- (void)actOnSubclassesOf:(Class)parentClass block:(void (^)(Class))block;

@end

NS_ASSUME_NONNULL_END
