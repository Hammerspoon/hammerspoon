#import "SentrySubClassFinder.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryObjCRuntimeWrapper.h"
#import <objc/runtime.h>
#import <string.h>

@interface
SentrySubClassFinder ()

@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) id<SentryObjCRuntimeWrapper> objcRuntimeWrapper;

@end

@implementation SentrySubClassFinder

- (instancetype)initWithDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                   objcRuntimeWrapper:(id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
{
    if (self = [super init]) {
        self.dispatchQueue = dispatchQueue;
        self.objcRuntimeWrapper = objcRuntimeWrapper;
    }
    return self;
}

- (void)actOnSubclassesOfViewControllerInImage:(NSString *)imageName block:(void (^)(Class))block;
{
    [self.dispatchQueue dispatchAsyncWithBlock:^{
        Class viewControllerClass = NSClassFromString(@"UIViewController");
        if (viewControllerClass == nil) {
            SENTRY_LOG_DEBUG(@"UIViewController class not found.");
            return;
        }

        unsigned int count = 0;
        const char **classes = [self.objcRuntimeWrapper
            copyClassNamesForImage:[imageName cStringUsingEncoding:NSUTF8StringEncoding]
                            amount:&count];

        // Storing the actual classes in an NSArray would call initializer of the class, which we
        // must avoid as we are on a background thread here and dealing with UIViewControllers,
        // which assume they are running on the main thread. Therefore, we store the class name
        // instead so we can search for the subclasses on a background thread. We can't use
        // NSObject:isSubclassOfClass as not all classes in the runtime in classes inherit from
        // NSObject and a call to isSubclassOfClass would call the initializer of the class, which
        // we can't allow because of the problem with UIViewControllers mentioned above.
        //
        // Turn out the approach to search all the view controllers inside the app binary image is
        // fast and we don't need to include this restriction that will cause confusion.
        // In a project with 1000 classes (a big project), it took only ~3ms to check all classes.
        NSMutableArray<NSString *> *classesToSwizzle = [NSMutableArray new];
        for (int i = 0; i < count; i++) {
            NSString *className = [NSString stringWithUTF8String:classes[i]];
            Class class = NSClassFromString(className);
            if ([self isClass:class subClassOf:viewControllerClass]) {
                [classesToSwizzle addObject:className];
            }
        }

        free(classes);
        [self.dispatchQueue dispatchAsyncOnMainQueue:^{
            for (NSString *className in classesToSwizzle) {
                block(NSClassFromString(className));
            }

            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"The following UIViewControllers will "
                                                          @"generate automatic transactions: %@",
                                         [classesToSwizzle componentsJoinedByString:@", "]]
                      andLevel:kSentryLevelDebug];
        }];
    }];
}

- (BOOL)isClass:(Class)childClass subClassOf:(Class)parentClass
{
    if (!childClass || childClass == parentClass) {
        return false;
    }

    // Using a do while loop, like pointed out in Cocoa with Love
    // (https://www.cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html)
    // can lead to EXC_I386_GPFLT which, stands for General Protection Fault and means we
    // are doing something we shouldn't do. It's safer to use a regular while loop to check
    // if superClass is valid.
    while (childClass && childClass != parentClass) {
        childClass = class_getSuperclass(childClass);
    }

    return childClass != nil;
}

@end
