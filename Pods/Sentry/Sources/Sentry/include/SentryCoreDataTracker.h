#import "SentryDefines.h"
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryNSProcessInfoWrapper;
@class SentryThreadInspector;

@interface SentryCoreDataTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithThreadInspector:(SentryThreadInspector *)threadInspector
                     processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper;

- (NSArray *)managedObjectContext:(NSManagedObjectContext *)context
              executeFetchRequest:(NSFetchRequest *)request
                            error:(NSError **)error
                      originalImp:(NSArray *_Nullable(NS_NOESCAPE ^)(NSFetchRequest *, NSError **))
                                      original NS_REFINED_FOR_SWIFT;

- (BOOL)managedObjectContext:(NSManagedObjectContext *)context
                        save:(NSError **)error
                 originalImp:(BOOL(NS_NOESCAPE ^)(NSError **))original;

@end

NS_ASSUME_NONNULL_END
