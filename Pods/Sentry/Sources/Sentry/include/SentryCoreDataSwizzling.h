
#import "SentryDefines.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryCoreDataMiddleware

- (NSArray *)managedObjectContext:(NSManagedObjectContext *)context
              executeFetchRequest:(NSFetchRequest *)request
                            error:(NSError **)error
                      originalImp:(NSArray *_Nullable(NS_NOESCAPE ^)(NSFetchRequest *, NSError **))
                                      original NS_REFINED_FOR_SWIFT;

- (BOOL)managedObjectContext:(NSManagedObjectContext *)context
                        save:(NSError **)error
                 originalImp:(BOOL(NS_NOESCAPE ^)(NSError **))original
    NS_SWIFT_NAME(saveManagedObjectContext(_:originalImp:));

@end

@interface SentryCoreDataSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly, nonatomic) SentryCoreDataSwizzling *sharedInstance;

@property (nonatomic, readonly, nullable) id<SentryCoreDataMiddleware> middleware;

- (void)startWithMiddleware:(id<SentryCoreDataMiddleware>)middleware;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
