#import <Foundation/Foundation.h>

#pragma mark - Macros Based API

/// A macro for wrapping the return type of the swizzled method.
#define SentrySWReturnType(type) type

/// A macro for wrapping arguments of the swizzled method.
#define SentrySWArguments(arguments...) _SentrySWArguments(arguments)

/// A macro for wrapping the replacement code for the swizzled method.
#define SentrySWReplacement(code...) code

/// A macro for casting and calling original implementation.
/// May be used only in SentrySwizzleInstanceMethod or SentrySwizzleClassMethod
/// macros.
#define SentrySWCallOriginal(arguments...) _SentrySWCallOriginal(arguments)

#pragma mark └ Swizzle Instance Method

/**
 Swizzles the instance method of the class with the new implementation.

 Example for swizzling `-(int)calculate:(int)number;` method:

 @code

    SentrySwizzleInstanceMethod(classToSwizzle,
                            @selector(calculate:),
                            SentrySWReturnType(int),
                            SentrySWArguments(int number),
                            SentrySWReplacement(
    {
        // Calling original implementation.
        int res = SentrySWCallOriginal(number);
        // Returning modified return value.
        return res + 1;
    }), 0, NULL);

 @endcode

 Swizzling frequently goes along with checking whether this particular class (or
 one of its superclasses) has been already swizzled. Here the
 `SentrySwizzleMode` and `key` parameters can help. See +[SentrySwizzle
 swizzleInstanceMethod:inClass:newImpFactory:mode:key:] for details.

 Swizzling is fully thread-safe.

 @param classToSwizzle The class with the method that should be swizzled.

 @param selector Selector of the method that should be swizzled.

 @param SentrySWReturnType The return type of the swizzled method wrapped in the
 SentrySWReturnType macro.

 @param SentrySWArguments The arguments of the swizzled method wrapped in the
 SentrySWArguments macro.

 @param SentrySWReplacement The code of the new implementation of the swizzled
 method wrapped in the SentrySWReplacement macro.

 @param SentrySwizzleMode The mode is used in combination with the key to
 indicate whether the swizzling should be done for the given class. You can pass
 0 for SentrySwizzleModeAlways.

 @param key The key is used in combination with the mode to indicate whether the
 swizzling should be done for the given class. May be NULL if the mode is
 SentrySwizzleModeAlways.

 @return YES if successfully swizzled and NO if swizzling has been already done
 for given key and class (or one of superclasses, depends on the mode).

 */
#define SentrySwizzleInstanceMethod(classToSwizzle, selector, SentrySWReturnType,                  \
    SentrySWArguments, SentrySWReplacement, SentrySwizzleMode, key)                                \
    _SentrySwizzleInstanceMethod(classToSwizzle, selector, SentrySWReturnType,                     \
        _SentrySWWrapArg(SentrySWArguments), _SentrySWWrapArg(SentrySWReplacement),                \
        SentrySwizzleMode, key)

#pragma mark └ Swizzle Class Method

/**
 Swizzles the class method of the class with the new implementation.

 Example for swizzling `+(int)calculate:(int)number;` method:

 @code

    SentrySwizzleClassMethod(classToSwizzle,
                         @selector(calculate:),
                         SentrySWReturnType(int),
                         SentrySWArguments(int number),
                         SentrySWReplacement(
    {
        // Calling original implementation.
        int res = SentrySWCallOriginal(number);
        // Returning modified return value.
        return res + 1;
    }));

 @endcode

 Swizzling is fully thread-safe.

 @param classToSwizzle The class with the method that should be swizzled.

 @param selector Selector of the method that should be swizzled.

 @param SentrySWReturnType The return type of the swizzled method wrapped in the
 SentrySWReturnType macro.

 @param SentrySWArguments The arguments of the swizzled method wrapped in the
 SentrySWArguments macro.

 @param SentrySWReplacement The code of the new implementation of the swizzled
 method wrapped in the SentrySWReplacement macro.

 */
#define SentrySwizzleClassMethod(                                                                  \
    classToSwizzle, selector, SentrySWReturnType, SentrySWArguments, SentrySWReplacement)          \
    _SentrySwizzleClassMethod(classToSwizzle, selector, SentrySWReturnType,                        \
        _SentrySWWrapArg(SentrySWArguments), _SentrySWWrapArg(SentrySWReplacement))

#pragma mark - Main API

/**
 A function pointer to the original implementation of the swizzled method.
 */
typedef void (*SentrySwizzleOriginalIMP)(void /* id, SEL, ... */);

/**
 SentrySwizzleInfo is used in the new implementation block to get and call
 original implementation of the swizzled method.
 */
@interface SentrySwizzleInfo : NSObject

/**
 Returns the original implementation of the swizzled method.

 It is actually either an original implementation if the swizzled class
 implements the method itself; or a super implementation fetched from one of the
 superclasses.

 @note You must always cast returned implementation to the appropriate function
 pointer when calling.

 @return A function pointer to the original implementation of the swizzled
 method.
 */
- (SentrySwizzleOriginalIMP)getOriginalImplementation;

/// The selector of the swizzled method.
@property (nonatomic, readonly) SEL selector;

@end

/**
 A factory block returning the block for the new implementation of the swizzled
 method.

 You must always obtain original implementation with swizzleInfo and call it
 from the new implementation.

 @param swizzleInfo An info used to get and call the original implementation of
 the swizzled method.

 @return A block that implements a method.
    Its signature should be: `method_return_type ^(id self, method_args...)`.
    The selector is not available as a parameter to this block.
 */
typedef id (^SentrySwizzleImpFactoryBlock)(SentrySwizzleInfo *swizzleInfo);

typedef NS_ENUM(NSUInteger, SentrySwizzleMode) {
    /// SentrySwizzle always does swizzling.
    SentrySwizzleModeAlways = 0,
    /// SentrySwizzle does not do swizzling if the same class has been swizzled
    /// earlier with the same key.
    SentrySwizzleModeOncePerClass = 1,
    /// SentrySwizzle does not do swizzling if the same class or one of its
    /// superclasses have been swizzled earlier with the same key.
    /// @note There is no guarantee that your implementation will be called only
    /// once per method call. If the order of swizzling is: first inherited
    /// class, second superclass, then both swizzlings will be done and the new
    /// implementation will be called twice.
    SentrySwizzleModeOncePerClassAndSuperclasses = 2
};

@interface SentrySwizzle : NSObject

#pragma mark └ Swizzle Instance Method

/**
 Swizzles the instance method of the class with the new implementation.

 Original implementation must always be called from the new implementation. And
 because of the the fact that for safe and robust swizzling original
 implementation must be dynamically fetched at the time of calling and not at
 the time of swizzling, swizzling API is a little bit complicated.

 You should pass a factory block that returns the block for the new
 implementation of the swizzled method. And use swizzleInfo argument to retrieve
 and call original implementation.

 Example for swizzling `-(int)calculate:(int)number;` method:

 @code

    SEL selector = @selector(calculate:);
    [SentrySwizzle
     swizzleInstanceMethod:selector
     inClass:classToSwizzle
     newImpFactory:^id(SentrySwizzleInfo *swizzleInfo) {
         // This block will be used as the new implementation.
         return ^int(__unsafe_unretained id self, int num){
             // You MUST always cast implementation to the correct function
 pointer. int (*originalIMP)(__unsafe_unretained id, SEL, int); originalIMP =
 (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
             // Calling original implementation.
             int res = originalIMP(self,selector,num);
             // Returning modified return value.
             return res + 1;
         };
     }
     mode:SentrySwizzleModeAlways
     key:NULL];

 @endcode

 Swizzling frequently goes along with checking whether this particular class (or
 one of its superclasses) has been already swizzled. Here the `mode` and `key`
 parameters can help.

 Here is an example of swizzling `-(void)dealloc;` only in case when neither
 class and no one of its superclasses has been already swizzled with our key.
 However "Deallocating ..." message still may be logged multiple times per
 method call if swizzling was called primarily for an inherited class and later
 for one of its superclasses.

 @code

    static const void *key = &key;
    SEL selector = NSSelectorFromString(@"dealloc");
    [SentrySwizzle
     swizzleInstanceMethod:selector
     inClass:classToSwizzle
     newImpFactory:^id(SentrySwizzleInfo *swizzleInfo) {
         return ^void(__unsafe_unretained id self){
             NSLog(@"Deallocating %@.",self);

             void (*originalIMP)(__unsafe_unretained id, SEL);
             originalIMP = (__typeof(originalIMP))[swizzleInfo
 getOriginalImplementation]; originalIMP(self,selector);
         };
     }
     mode:SentrySwizzleModeOncePerClassAndSuperclasses
     key:key];

 @endcode

 Swizzling is fully thread-safe.

 @param selector Selector of the method that should be swizzled.

 @param classToSwizzle The class with the method that should be swizzled.

 @param factoryBlock The factory block returning the block for the new
 implementation of the swizzled method.

 @param mode The mode is used in combination with the key to indicate whether
 the swizzling should be done for the given class.

 @param key The key is used in combination with the mode to indicate whether the
 swizzling should be done for the given class. May be NULL if the mode is
 SentrySwizzleModeAlways.

 @return YES if successfully swizzled and NO if swizzling has been already done
 for given key and class (or one of superclasses, depends on the mode).
 */
+ (BOOL)swizzleInstanceMethod:(SEL)selector
                      inClass:(Class)classToSwizzle
                newImpFactory:(SentrySwizzleImpFactoryBlock)factoryBlock
                         mode:(SentrySwizzleMode)mode
                          key:(const void *)key;

#pragma mark └ Swizzle Class method

/**
 Swizzles the class method of the class with the new implementation.

 Original implementation must always be called from the new implementation. And
 because of the the fact that for safe and robust swizzling original
 implementation must be dynamically fetched at the time of calling and not at
 the time of swizzling, swizzling API is a little bit complicated.

 You should pass a factory block that returns the block for the new
 implementation of the swizzled method. And use swizzleInfo argument to retrieve
 and call original implementation.

 Example for swizzling `+(int)calculate:(int)number;` method:

 @code

    SEL selector = @selector(calculate:);
    [SentrySwizzle
     swizzleClassMethod:selector
     inClass:classToSwizzle
     newImpFactory:^id(SentrySwizzleInfo *swizzleInfo) {
         // This block will be used as the new implementation.
         return ^int(__unsafe_unretained id self, int num){
             // You MUST always cast implementation to the correct function
 pointer. int (*originalIMP)(__unsafe_unretained id, SEL, int); originalIMP =
 (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
             // Calling original implementation.
             int res = originalIMP(self,selector,num);
             // Returning modified return value.
             return res + 1;
         };
     }];

 @endcode

 Swizzling is fully thread-safe.

 @param selector Selector of the method that should be swizzled.

 @param classToSwizzle The class with the method that should be swizzled.

 @param factoryBlock The factory block returning the block for the new
 implementation of the swizzled method.
 */
+ (void)swizzleClassMethod:(SEL)selector
                   inClass:(Class)classToSwizzle
             newImpFactory:(SentrySwizzleImpFactoryBlock)factoryBlock;

@end

#pragma mark - Implementation details
// Do not write code that depends on anything below this line.

// Wrapping arguments to pass them as a single argument to another macro.
#define _SentrySWWrapArg(args...) args

#define _SentrySWDel2Arg(a1, a2, args...) a1, ##args
#define _SentrySWDel3Arg(a1, a2, a3, args...) a1, a2, ##args

// To prevent comma issues if there are no arguments we add one dummy argument
// and remove it later.
#define _SentrySWArguments(arguments...) DEL, ##arguments

#define _SentrySwizzleInstanceMethod(classToSwizzle, selector, SentrySWReturnType,                 \
    SentrySWArguments, SentrySWReplacement, SentrySwizzleMode, KEY)                                \
    [SentrySwizzle                                                                                 \
        swizzleInstanceMethod:selector                                                             \
                      inClass:[classToSwizzle class]                                               \
                newImpFactory:^id(SentrySwizzleInfo *swizzleInfo) {                                \
                    SentrySWReturnType (*originalImplementation_)(                                 \
                        _SentrySWDel3Arg(__unsafe_unretained id, SEL, SentrySWArguments));         \
                    SEL selector_ = selector;                                                      \
                    return ^SentrySWReturnType(_SentrySWDel2Arg(                                   \
                        __unsafe_unretained id self, SentrySWArguments)) { SentrySWReplacement };  \
                }                                                                                  \
                         mode:SentrySwizzleMode                                                    \
                          key:KEY];

#define _SentrySwizzleClassMethod(                                                                 \
    classToSwizzle, selector, SentrySWReturnType, SentrySWArguments, SentrySWReplacement)          \
    [SentrySwizzle                                                                                 \
        swizzleClassMethod:selector                                                                \
                   inClass:[classToSwizzle class]                                                  \
             newImpFactory:^id(SentrySwizzleInfo *swizzleInfo) {                                   \
                 SentrySWReturnType (*originalImplementation_)(                                    \
                     _SentrySWDel3Arg(__unsafe_unretained id, SEL, SentrySWArguments));            \
                 SEL selector_ = selector;                                                         \
                 return ^SentrySWReturnType(_SentrySWDel2Arg(                                      \
                     __unsafe_unretained id self, SentrySWArguments)) { SentrySWReplacement };     \
             }];

#define _SentrySWCallOriginal(arguments...)                                                        \
    ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(                  \
        self, selector_, ##arguments)
