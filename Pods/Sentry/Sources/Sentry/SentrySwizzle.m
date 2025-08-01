#import "SentrySwizzle.h"
#import "SentryLogC.h"

#import <objc/runtime.h>
#include <pthread.h>

#pragma mark - Swizzling

#pragma mark └ SentrySwizzleInfo

typedef IMP (^SentrySwizzleImpProvider)(void);

@interface SentrySwizzleInfo ()
@property (nonatomic, copy) SentrySwizzleImpProvider impProviderBlock;
@property (nonatomic, readwrite) SEL selector;
@end

@implementation SentrySwizzleInfo

- (SentrySwizzleOriginalIMP)getOriginalImplementation
{
    NSAssert(_impProviderBlock, @"_impProviderBlock can't be missing");
    if (!_impProviderBlock) {
        SENTRY_LOG_ERROR(@"_impProviderBlock can't be missing");
        return NULL;
    }

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    @synchronized(self) {
        self.originalCalled = YES;
    }
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

    // Casting IMP to SentrySwizzleOriginalIMP to force user casting.
    return (SentrySwizzleOriginalIMP)_impProviderBlock();
}

@end

#pragma mark └ SentrySwizzle

@implementation SentrySwizzle

// This lock is shared by all swizzling and unswizzling calls to ensure that
// only one thread is modifying the class at a time.
static pthread_mutex_t gLock = PTHREAD_MUTEX_INITIALIZER;

#if SENTRY_TEST || SENTRY_TEST_CI
/**
 * - Returns: a dictionary that maps keys to the references to the original implementations.
 */
static NSMutableDictionary<NSValue *, NSValue *> *
refsToOriginalImplementationsDictionary(void)
{
    static NSMutableDictionary *refsToOriginalImplementations;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ refsToOriginalImplementations = [NSMutableDictionary new]; });
    return refsToOriginalImplementations;
}

/**
 * Adds a reference to the original implementation to the dictionary.
 *
 * If the key is NULL, it will log an error and NOT store the reference.
 *
 * - Parameter key: The key for which to store the reference to the original implementation.
 * - Parameter implementation: Reference to the original implementation to store.
 */
static void
storeRefToOriginalImplementation(const void *key, IMP implementation)
{
    NSCAssert(key != NULL, @"Key may not be NULL.");
    if (key == NULL) {
        SENTRY_LOG_ERROR(@"Key may not be NULL.");
        return;
    }
    NSMutableDictionary<NSValue *, NSValue *> *refsToOriginalImplementations
        = refsToOriginalImplementationsDictionary();
    NSValue *keyValue = [NSValue valueWithPointer:key];
    refsToOriginalImplementations[keyValue] = [NSValue valueWithPointer:implementation];
}

/**
 * Removes a reference to the original implementation from the dictionary.
 *
 * If the key is NULL, it will log an error and do nothing.
 *
 * - Parameter key: The key for which to remove the reference to the original implementation.
 */
static void
removeRefToOriginalImplementation(const void *key)
{
    NSCAssert(key != NULL, @"Key may not be NULL.");
    if (key == NULL) {
        SENTRY_LOG_ERROR(@"Key may not be NULL.");
        return;
    }
    NSMutableDictionary<NSValue *, NSValue *> *refsToOriginalImplementations
        = refsToOriginalImplementationsDictionary();
    NSValue *keyValue = [NSValue valueWithPointer:key];
    [refsToOriginalImplementations removeObjectForKey:keyValue];
}

/**
 * Returns the original implementation for the given key.
 *
 * If the key is NULL, it will log an error and return NULL.
 * If no original implementation is found, it will return NULL.
 *
 * - Parameter key: The key for which to get the original implementation.
 * - Returns: The original implementation for the given key.
 */
static IMP
getRefToOriginalImplementation(const void *key)
{
    NSCAssert(key != NULL, @"Key may not be NULL.");
    if (key == NULL) {
        SENTRY_LOG_ERROR(@"Key may not be NULL.");
        return NULL;
    }
    NSMutableDictionary<NSValue *, NSValue *> *refsToOriginalImplementations
        = refsToOriginalImplementationsDictionary();
    NSValue *keyValue = [NSValue valueWithPointer:key];
    NSValue *originalImplementationValue = [refsToOriginalImplementations objectForKey:keyValue];
    if (originalImplementationValue == nil) {
        return NULL;
    }
    return (IMP)[originalImplementationValue pointerValue];
}
#endif // SENTRY_TEST || SENTRY_TEST_CI

static void
swizzle(
    Class classToSwizzle, SEL selector, SentrySwizzleImpFactoryBlock factoryBlock, const void *key)
{
    Method method = class_getInstanceMethod(classToSwizzle, selector);

    NSCAssert(NULL != method, @"Selector %@ not found in %@ methods of class %@.",
        NSStringFromSelector(selector), class_isMetaClass(classToSwizzle) ? @"class" : @"instance",
        classToSwizzle);

    // To keep things thread-safe, we fill in the originalIMP later,
    // with the result of the class_replaceMethod call below.
    __block IMP originalIMP = NULL;

    // This block will be called by the client to get original implementation
    // and call it.
    SentrySwizzleImpProvider originalImpProvider = ^IMP {
        // It's possible that another thread can call the method between the
        // call to class_replaceMethod and its return value being set. So to be
        // sure originalIMP has the right value, we need a lock.

        pthread_mutex_lock(&gLock);

        IMP imp = originalIMP;

        pthread_mutex_unlock(&gLock);

        if (NULL == imp) {
            // If the class does not implement the method
            // we need to find an implementation in one of the superclasses.
            Class superclass = class_getSuperclass(classToSwizzle);
            imp = method_getImplementation(class_getInstanceMethod(superclass, selector));
        }

        return imp;
    };

    SentrySwizzleInfo *swizzleInfo = [SentrySwizzleInfo new];
    swizzleInfo.selector = selector;
    swizzleInfo.impProviderBlock = originalImpProvider;

    // We ask the client for the new implementation block.
    // We pass swizzleInfo as an argument to factory block, so the client can
    // call original implementation from the new implementation.
    id newIMPBlock = factoryBlock(swizzleInfo);

    const char *methodType = method_getTypeEncoding(method);

    IMP newIMP = imp_implementationWithBlock(newIMPBlock);

    // Atomically replace the original method with our new implementation.
    // This will ensure that if someone else's code on another thread is messing
    // with the class' method list too, we always have a valid method at all
    // times.
    //
    // If the class does not implement the method itself then
    // class_replaceMethod returns NULL and superclasses's implementation will
    // be used.
    //
    // We need a lock to be sure that originalIMP has the right value in the
    // originalImpProvider block above.

    pthread_mutex_lock(&gLock);

    originalIMP = class_replaceMethod(classToSwizzle, selector, newIMP, methodType);
#if SENTRY_TEST || SENTRY_TEST_CI
    if (originalIMP) {
        if (key != NULL) {
            storeRefToOriginalImplementation(key, originalIMP);
        } else {
            SENTRY_LOG_WARN(
                @"Swizzling without a key is not recommended, because they can not be unswizzled.");
        }
    }
#endif // SENTRY_TEST || SENTRY_TEST_CI

    pthread_mutex_unlock(&gLock);
}

#if SENTRY_TEST || SENTRY_TEST_CI
static void
unswizzle(Class classToUnswizzle, SEL selector, const void *key)
{
    NSCAssert(key != NULL, @"Key may not be NULL.");
    if (key == NULL) {
        SENTRY_LOG_WARN(@"Key may not be NULL.");
        return;
    }

    Method method = class_getInstanceMethod(classToUnswizzle, selector);

    NSCAssert(NULL != method, @"Selector %@ not found in %@ methods of class %@.",
        NSStringFromSelector(selector),
        class_isMetaClass(classToUnswizzle) ? @"class" : @"instance", classToUnswizzle);

    pthread_mutex_lock(&gLock);

    IMP originalIMP = getRefToOriginalImplementation(key);
    if (originalIMP) {
        const char *methodType = method_getTypeEncoding(method);
        class_replaceMethod(classToUnswizzle, selector, originalIMP, methodType);

        removeRefToOriginalImplementation(key);
    }

    pthread_mutex_unlock(&gLock);
}
#endif // SENTRY_TEST || SENTRY_TEST_CI

static NSMutableDictionary<NSValue *, NSMutableSet<Class> *> *
swizzledClassesDictionary(void)
{
    static NSMutableDictionary *swizzledClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ swizzledClasses = [NSMutableDictionary new]; });
    return swizzledClasses;
}

static NSMutableSet<Class> *
swizzledClassesForKey(const void *key)
{
    NSMutableDictionary<NSValue *, NSMutableSet<Class> *> *classesDictionary
        = swizzledClassesDictionary();
    NSValue *keyValue = [NSValue valueWithPointer:key];
    NSMutableSet *swizzledClasses = [classesDictionary objectForKey:keyValue];
    if (!swizzledClasses) {
        swizzledClasses = [NSMutableSet new];
        [classesDictionary setObject:swizzledClasses forKey:keyValue];
    }
    return swizzledClasses;
}

+ (BOOL)swizzleInstanceMethod:(SEL)selector
                      inClass:(nonnull Class)classToSwizzle
                newImpFactory:(SentrySwizzleImpFactoryBlock)factoryBlock
                         mode:(SentrySwizzleMode)mode
                          key:(const void *)key
{
    NSAssert(!(key == NULL && mode != SentrySwizzleModeAlways),
        @"Key may not be NULL if mode is not SentrySwizzleModeAlways.");

    if (key == NULL && mode != SentrySwizzleModeAlways) {
        SENTRY_LOG_WARN(@"Key may not be NULL if mode is not SentrySwizzleModeAlways.");
        return NO;
    }

    @synchronized(swizzledClassesDictionary()) {
        if (key) {
            NSSet<Class> *swizzledClasses = swizzledClassesForKey(key);
            if (mode == SentrySwizzleModeOncePerClass) {
                if ([swizzledClasses containsObject:classToSwizzle]) {
                    return NO;
                }
            } else if (mode == SentrySwizzleModeOncePerClassAndSuperclasses) {
                for (Class currentClass = classToSwizzle; nil != currentClass;
                    currentClass = class_getSuperclass(currentClass)) {
                    if ([swizzledClasses containsObject:currentClass]) {
                        return NO;
                    }
                }
            }
        }

        swizzle(classToSwizzle, selector, factoryBlock, key);

        if (key) {
            [swizzledClassesForKey(key) addObject:classToSwizzle];
        }
    }

    return YES;
}

#if SENTRY_TEST || SENTRY_TEST_CI
+ (BOOL)unswizzleInstanceMethod:(SEL)selector inClass:(Class)classToUnswizzle key:(const void *)key
{
    NSAssert(key != NULL, @"Key may not be NULL.");
    if (key == NULL) {
        SENTRY_LOG_WARN(@"Key may not be NULL.");
        return NO;
    }

    @synchronized(swizzledClassesDictionary()) {
        NSSet<Class> *swizzledClasses = swizzledClassesForKey(key);
        if (![swizzledClasses containsObject:classToUnswizzle]) {
            return NO;
        }

        unswizzle(classToUnswizzle, selector, key);

        [swizzledClassesForKey(key) removeObject:classToUnswizzle];
    }

    return YES;
}
#endif // SENTRY_TEST || SENTRY_TEST_CI

+ (void)swizzleClassMethod:(SEL)selector
                   inClass:(Class)classToSwizzle
             newImpFactory:(SentrySwizzleImpFactoryBlock)factoryBlock
{
    [self swizzleInstanceMethod:selector
                        inClass:object_getClass(classToSwizzle)
                  newImpFactory:factoryBlock
                           mode:SentrySwizzleModeAlways
                            key:NULL];
}

@end
