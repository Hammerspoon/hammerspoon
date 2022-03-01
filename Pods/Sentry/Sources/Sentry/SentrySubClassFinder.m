#import "SentrySubClassFinder.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryObjCRuntimeWrapper.h"
#import <objc/runtime.h>

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

- (void)actOnSubclassesOf:(Class)parentClass block:(void (^)(Class))block
{
    [self.dispatchQueue dispatchAsyncWithBlock:^{
        Class *classes = NULL;
        int numClasses = -1;
        int attemptsForGettingClasses = 2;

        // The number of classes may change between the two invocations of class_getSuperclass. If
        // this or any other error happens, we retry once. We don't want to retry this in a loop
        // because of the danger of an endless loop.
        for (int i = 0; numClasses == -1 && i < attemptsForGettingClasses; i++) {
            numClasses = [self getClassList:&classes];

            if (numClasses < 0) {
                free(classes);
                classes = NULL;
            }
        }

        if (numClasses < 0) {
            NSString *msg =
                [NSString stringWithFormat:@"Not able to get subclasses for %@", parentClass];
            [SentryLog logWithMessage:msg andLevel:kSentryLevelError];
            return;
        }

        // Only for testing. We want to know in tests if the code iterated over the classes, because
        // iterating in edge cases could lead to crashses. Ideally, we would wrap
        // class_getSuperclass in the SentryObjCRuntimeWrapper and count its invocations. As
        // class_getSuperclass is called in a tight loop doing so would slow down the code
        // significantly. This is pragmatic workaround to find out in tests if the code iterated
        // over the classes.
        [self.objcRuntimeWrapper countIterateClasses];

        // Storing the actual classes in an NSArray would call initializer of the class, which we
        // must avoid as we are on a background thread here and dealing with UIViewControllers,
        // which assume they are running on the main thread. Therefore, we store the indexes instead
        // so we can search for the subclasses on a background thread.
        // We can't use NSObject:isSubclassOfClass as not all classes in the runtime in classes
        // inherit from NSObject and a call to isSubclassOfClass would call the initializer of the
        // class, which we can't allow because of the problem with UIViewControllers mentioned
        // above.

        NSMutableArray<NSNumber *> *indexesToSwizzle = [NSMutableArray new];
        for (NSInteger i = 0; i < numClasses; i++) {
            Class superClass = classes[i];

            // Don't add the parent class to list of sublcasses
            if (superClass == parentClass) {
                continue;
            }

            // Using a do while loop, like pointed out in Cocoa with Love
            // (https://www.cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html)
            // can lead to EXC_I386_GPFLT which, stands for General Protection Fault and means we
            // are doing something we shouldn't do. It's safer to use a regular while loop to check
            // if superClass is valid.
            while (superClass && superClass != parentClass) {
                superClass = class_getSuperclass(superClass);
            }

            if (superClass) {
                [indexesToSwizzle addObject:@(i)];
            }
        }

        [self.dispatchQueue dispatchOnMainQueue:^{
            for (NSNumber *i in indexesToSwizzle) {
                NSInteger index = [i integerValue];
                block(classes[index]);
            }
            free(classes);
        }];
    }];
}

- (int)getClassList:(Class **)classes
{
    int numClasses = [self.objcRuntimeWrapper getClassList:NULL bufferCount:0];

    if (numClasses <= 0) {
        return -1;
    }

    int memSize = sizeof(Class) * numClasses;
    *classes = (__unsafe_unretained Class *)malloc(memSize);

    if (classes == NULL && memSize) {
        [SentryLog logWithMessage:@"Couldn't allocate memory when retrieving class list."
                         andLevel:kSentryLevelError];
        return -1;
    }

    // Don't assign the result getClassList again to numClasses because if a class is registered
    // in the meantime our buffer would not be big enough and we would crash when iterating over
    // the classes.
    int secondNumClasses = [self.objcRuntimeWrapper getClassList:*classes bufferCount:numClasses];

    // When the number of classes changes between the invocation of class_getSuperclass, we run the
    // risk of accessing bad memory when iterating over all classes, also see
    // https://github.com/getsentry/sentry-cocoa/issues/1634
    if (secondNumClasses != numClasses) {
        [SentryLog logWithMessage:@"Can't find subclasses, because the number of classes changed "
                                  @"between invocations of class_getSuperclass."
                         andLevel:kSentryLevelDebug];
        return -1;
    }

    return numClasses;
}

@end
