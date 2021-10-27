#import "SentrySubClassFinder.h"
#import "SentryDefines.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryObjCRuntimeWrapper.h"
#import <Foundation/Foundation.h>
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
        int numClasses = [self.objcRuntimeWrapper getClassList:NULL bufferCount:0];

        if (numClasses <= 0) {
            NSString *msg =
                [NSString stringWithFormat:@"No classes found when retrieving class list for %@.",
                          parentClass];
            [SentryLog logWithMessage:msg andLevel:kSentryLevelError];
            return;
        }

        int memSize = sizeof(Class) * numClasses;
        Class *classes = (__unsafe_unretained Class *)malloc(memSize);

        if (classes == NULL && memSize) {
            NSString *msg = [NSString
                stringWithFormat:@"Couldn't allocate memory for retrieving class list for %@",
                parentClass];
            [SentryLog logWithMessage:msg andLevel:kSentryLevelError];
            return;
        }

        // Don't assign the result getClassList again to numClasses because if a class is registered
        // in the meantime our buffer would not be big enough and we would crash when iterating over
        // the classes below.
        int secondNumClasses = [self.objcRuntimeWrapper getClassList:classes
                                                         bufferCount:numClasses];

        // Only set the numClasses to secondNumClasses in the very unlikely case the number of
        // classes decreased. If the number of classes increased, which can happen, we only iterate
        // over the inital number of classes. We don't want to retry the whole process and are fine
        // with possibly skipping a few newly added classes as they could anyway be added later in
        // the lifetime of the app.
        if (secondNumClasses < numClasses) {
            numClasses = secondNumClasses;
        }

        // Storing the actual classes in an NSArray would call initialize of the class, which we
        // must avoid as we are on a background thread here and dealing with UIViewControllers,
        // which assume they are running on the main thread. Therefore, we store the indexes instead
        // so we can search for the subclasses on a background thread.
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

            if (superClass != nil) {
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

@end
