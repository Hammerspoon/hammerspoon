
#import "SentryCoreDataTracker.h"
#import "SentryFrame.h"
#import "SentryHub+Private.h"
#import "SentryInternalDefines.h"
#import "SentryLog.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryPredicateDescriptor.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpan.h"
#import "SentrySpanProtocol.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThreadInspector.h"
#import "SentryTraceOrigins.h"

@implementation SentryCoreDataTracker {
    SentryPredicateDescriptor *predicateDescriptor;
    SentryThreadInspector *_threadInspector;
    SentryNSProcessInfoWrapper *_processInfoWrapper;
}

- (instancetype)initWithThreadInspector:(SentryThreadInspector *)threadInspector
                     processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper;
{
    if (self = [super init]) {
        predicateDescriptor = [[SentryPredicateDescriptor alloc] init];
        _threadInspector = threadInspector;
        _processInfoWrapper = processInfoWrapper;
    }
    return self;
}

- (NSArray *)managedObjectContext:(NSManagedObjectContext *)context
              executeFetchRequest:(NSFetchRequest *)request
                            error:(NSError **)error
                      originalImp:(NSArray *(NS_NOESCAPE ^)(NSFetchRequest *, NSError **))original
{
    __block id<SentrySpan> fetchSpan;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        fetchSpan = [span startChildWithOperation:SENTRY_COREDATA_FETCH_OPERATION
                                      description:[self descriptionFromRequest:request]];
        fetchSpan.origin = SentryTraceOriginAutoDBCoreData;
    }];

    if (fetchSpan) {
        SENTRY_LOG_DEBUG(@"SentryCoreDataTracker automatically started a new span with "
                         @"description: %@, operation: %@",
            fetchSpan.description, fetchSpan.operation);
    }

    NSArray *result = original(request, error);

    if (fetchSpan) {
        [self addExtraInfoToSpan:fetchSpan withContext:context];

        [fetchSpan setDataValue:[NSNumber numberWithInteger:result.count] forKey:@"read_count"];
        [fetchSpan
            finishWithStatus:result == nil ? kSentrySpanStatusInternalError : kSentrySpanStatusOk];

        SENTRY_LOG_DEBUG(@"SentryCoreDataTracker automatically finished span with status: %@",
            result == nil ? @"error" : @"ok");
    }

    return result;
}

- (BOOL)managedObjectContext:(NSManagedObjectContext *)context
                        save:(NSError **)error
                 originalImp:(BOOL(NS_NOESCAPE ^)(NSError **))original
{

    __block id<SentrySpan> saveSpan = nil;
    if (context.hasChanges) {
        __block NSDictionary<NSString *, NSDictionary *> *operations =
            [self groupEntitiesOperations:context];

        [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
            saveSpan = [span startChildWithOperation:SENTRY_COREDATA_SAVE_OPERATION
                                         description:[self descriptionForOperations:operations
                                                                          inContext:context]];
            saveSpan.origin = SentryTraceOriginAutoDBCoreData;
        }];

        if (saveSpan) {
            SENTRY_LOG_DEBUG(@"SentryCoreDataTracker automatically started a new span with "
                             @"description: %@, operation: %@",
                saveSpan.description, saveSpan.operation);

            [saveSpan setDataValue:operations forKey:@"operations"];
        } else {
            SENTRY_LOG_ERROR(@"managedObjectContext:save:originalImp: saveSpan is nil");
        }
    }

    BOOL result = original(error);

    if (saveSpan) {
        [self addExtraInfoToSpan:saveSpan withContext:context];
        [saveSpan finishWithStatus:result ? kSentrySpanStatusOk : kSentrySpanStatusInternalError];

        SENTRY_LOG_DEBUG(@"SentryCoreDataTracker automatically finished span with status: %@",
            result ? @"ok" : @"error");
    }

    return result;
}

- (void)addExtraInfoToSpan:(SentrySpan *)span withContext:(NSManagedObjectContext *)context
{
    BOOL isMainThread = [NSThread isMainThread];

    [span setDataValue:@(isMainThread) forKey:SPAN_DATA_BLOCKED_MAIN_THREAD];
    NSMutableArray<NSString *> *systems = [NSMutableArray<NSString *> array];
    NSMutableArray<NSString *> *names = [NSMutableArray<NSString *> array];
    [context.persistentStoreCoordinator.persistentStores enumerateObjectsUsingBlock:^(
        __kindof NSPersistentStore *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [systems addObject:obj.type];
        if (obj.URL != nil) {
            [names addObject:obj.URL.path];
        } else {
            [names addObject:@"(null)"];
        }
    }];
    [span setDataValue:[systems componentsJoinedByString:@";"] forKey:@"db.system"];
    [span setDataValue:[names componentsJoinedByString:@";"] forKey:@"db.name"];

    if (!isMainThread) {
        return;
    }

    SentryStacktrace *stackTrace = [_threadInspector stacktraceForCurrentThreadAsyncUnsafe];
    [span setFrames:stackTrace.frames];
}

- (NSString *)descriptionForOperations:
                  (NSDictionary<NSString *, NSDictionary<NSString *, NSNumber *> *> *)operations
                             inContext:(NSManagedObjectContext *)context
{
    __block NSMutableArray *resultParts = [NSMutableArray new];

    void (^operationInfo)(NSUInteger, NSString *) = ^void(NSUInteger total, NSString *op) {
        NSDictionary *items = operations[op];
        if (items && items.count > 0) {
            if (items.count == 1) {
                [resultParts addObject:[NSString stringWithFormat:@"%@ %@ '%@'", op,
                                                 items.allValues[0], items.allKeys[0]]];
            } else {
                [resultParts addObject:[NSString stringWithFormat:@"%@ %lu items", op,
                                                 (unsigned long)total]];
            }
        }
    };

    operationInfo(context.insertedObjects.count, @"INSERTED");
    operationInfo(context.updatedObjects.count, @"UPDATED");
    operationInfo(context.deletedObjects.count, @"DELETED");

    return [resultParts componentsJoinedByString:@", "];
}

- (NSDictionary<NSString *, NSDictionary *> *)groupEntitiesOperations:
    (NSManagedObjectContext *)context
{
    NSMutableDictionary<NSString *, NSDictionary *> *operations =
        [[NSMutableDictionary alloc] initWithCapacity:3];

    if (context.insertedObjects.count > 0)
        [operations setValue:[self countEntities:context.insertedObjects] forKey:@"INSERTED"];
    if (context.updatedObjects.count > 0)
        [operations setValue:[self countEntities:context.updatedObjects] forKey:@"UPDATED"];
    if (context.deletedObjects.count > 0)
        [operations setValue:[self countEntities:context.deletedObjects] forKey:@"DELETED"];

    return operations;
}

- (NSDictionary<NSString *, NSNumber *> *)countEntities:(NSSet *)entities
{
    NSMutableDictionary<NSString *, NSNumber *> *result = [NSMutableDictionary new];

    for (id item in entities) {
        NSString *cl
            = ((NSManagedObject *)item).entity.name ?: [SwiftDescriptor getObjectClassName:item];
        NSNumber *count = result[cl];
        result[cl] = [NSNumber numberWithInt:count.intValue + 1];
    }

    return result;
}

- (NSString *)descriptionFromRequest:(NSFetchRequest *)request
{
    NSMutableString *result =
        [[NSMutableString alloc] initWithFormat:@"SELECT '%@'", request.entityName];

    if (request.predicate) {
        [result appendFormat:@" WHERE %@",
                [predicateDescriptor predicateDescription:request.predicate]];
    }

    if (request.sortDescriptors.count > 0) {
        [result appendFormat:@" SORT BY %@", [self sortDescription:request.sortDescriptors]];
    }

    return result;
}

- (NSString *)sortDescription:(NSArray<NSSortDescriptor *> *)sortList
{
    NSMutableArray<NSString *> *fields = [[NSMutableArray alloc] initWithCapacity:sortList.count];
    for (NSSortDescriptor *descriptor in sortList) {
        NSString *direction = descriptor.ascending ? @"" : @" DESCENDING";
        [fields addObject:[NSString stringWithFormat:@"%@%@", descriptor.key, direction]];
    }
    return [fields componentsJoinedByString:@", "];
}

@end
