
#import "SentryCoreDataSwizzling.h"
#import "SentryCoreDataTracker.h"
#import "SentrySwizzle.h"

@implementation SentryCoreDataSwizzling

+ (SentryCoreDataSwizzling *)sharedInstance
{
    static SentryCoreDataSwizzling *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startWithTracker:(SentryCoreDataTracker *)coreDataTracker;
{
    // We just need to swizzle once, than we can control execution with the middleware.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ [self swizzleCoreData]; });

    _coreDataTracker = coreDataTracker;
}

- (void)stop
{
    _coreDataTracker = nil;
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

- (void)swizzleCoreData
{
    SEL fetchSelector = NSSelectorFromString(@"executeFetchRequest:error:");

    SentrySwizzleInstanceMethod(NSManagedObjectContext.class, fetchSelector,
        SentrySWReturnType(NSArray *),
        SentrySWArguments(NSFetchRequest * originalRequest, NSError * *error), SentrySWReplacement({
            NSArray *result;

            SentryCoreDataTracker *tracker = SentryCoreDataSwizzling.sharedInstance.coreDataTracker;

            if (tracker) {
                result = [tracker
                    managedObjectContext:self
                     executeFetchRequest:originalRequest
                                   error:error
                             originalImp:^NSArray *(NSFetchRequest *request, NSError **outError) {
                                 return SentrySWCallOriginal(request, outError);
                             }];
            } else {
                result = SentrySWCallOriginal(originalRequest, error);
            }

            return result;
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)fetchSelector);

    SEL saveSelector = NSSelectorFromString(@"save:");
    SentrySwizzleInstanceMethod(NSManagedObjectContext.class, saveSelector,
        SentrySWReturnType(BOOL), SentrySWArguments(NSError * *error), SentrySWReplacement({
            BOOL result;
            SentryCoreDataTracker *tracker = SentryCoreDataSwizzling.sharedInstance.coreDataTracker;

            if (tracker) {
                result = [tracker managedObjectContext:self
                                                  save:error
                                           originalImp:^BOOL(NSError **outError) {
                                               return SentrySWCallOriginal(outError);
                                           }];
            } else {
                result = SentrySWCallOriginal(error);
            }

            return result;
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)saveSelector);
}

#pragma clang diagnostic pop

@end
