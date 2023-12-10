
#import "SentryCoreDataSwizzling.h"
#import "SentrySwizzle.h"

@interface
SentryCoreDataSwizzling ()

@property (nonatomic, strong) id<SentryCoreDataMiddleware> middleware;

@end

@implementation SentryCoreDataSwizzling

+ (SentryCoreDataSwizzling *)sharedInstance
{
    static SentryCoreDataSwizzling *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startWithMiddleware:(id<SentryCoreDataMiddleware>)middleware
{
    // We just need to swizzle once, than we can control execution with the middleware.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ [self swizzleCoreData]; });

    self.middleware = middleware;
}

- (void)stop
{
    self.middleware = nil;
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

            id<SentryCoreDataMiddleware> middleware
                = SentryCoreDataSwizzling.sharedInstance.middleware;

            if (middleware) {
                result = [middleware
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
            id<SentryCoreDataMiddleware> middleware
                = SentryCoreDataSwizzling.sharedInstance.middleware;

            if (middleware) {
                result = [middleware managedObjectContext:self
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
