#import "SentryPerformanceTracker.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanId.h"
#import "SentrySpanProtocol.h"
#import "SentryTracer.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryPerformanceTracker ()

@property (nonatomic, strong) NSMutableDictionary<SentrySpanId *, id<SentrySpan>> *spans;
@property (nonatomic, strong) NSMutableArray<id<SentrySpan>> *activeSpanStack;

@end

@implementation SentryPerformanceTracker

+ (instancetype)shared
{
    static SentryPerformanceTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.spans = [[NSMutableDictionary alloc] init];
        self.activeSpanStack = [[NSMutableArray alloc] init];
    }
    return self;
}

- (SentrySpanId *)startSpanWithName:(NSString *)name operation:(NSString *)operation
{
    id<SentrySpan> activeSpan;
    @synchronized(self.activeSpanStack) {
        activeSpan = [self.activeSpanStack lastObject];
    }

    id<SentrySpan> newSpan;
    if (activeSpan != nil) {
        newSpan = [activeSpan startChildWithOperation:operation description:name];
    } else {
        SentryTransactionContext *context =
            [[SentryTransactionContext alloc] initWithName:name operation:operation];
        newSpan =
            [SentrySDK.currentHub startTransactionWithContext:context
                                                  bindToScope:SentrySDK.currentHub.scope.span == nil
                                              waitForChildren:YES
                                        customSamplingContext:@{}];
    }

    SentrySpanId *spanId = newSpan.context.spanId;

    if (spanId != nil) {
        @synchronized(self.spans) {
            self.spans[spanId] = newSpan;
        }
    } else {
        [SentryLog logWithMessage:@"startSpanWithName:operation: spanId is nil."
                         andLevel:kSentryLevelError];
        return [SentrySpanId empty];
    }

    return spanId;
}

- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                           inBlock:(void (^)(void))block
{
    SentrySpanId *spanId = [self startSpanWithName:description operation:operation];
    [self pushActiveSpan:spanId];
    block();
    [self popActiveSpan];
    [self finishSpan:spanId];
}

- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                      parentSpanId:(SentrySpanId *)parentSpanId
                           inBlock:(void (^)(void))block
{
    [self activateSpan:parentSpanId
           duringBlock:^{
               [self measureSpanWithDescription:description operation:operation inBlock:block];
           }];
}

- (void)activateSpan:(SentrySpanId *)spanId duringBlock:(void (^)(void))block
{

    if ([self pushActiveSpan:spanId]) {
        block();
        [self popActiveSpan];
    } else {
        block();
    }
}

- (nullable SentrySpanId *)activeSpanId
{
    @synchronized(self.activeSpanStack) {
        return [self.activeSpanStack lastObject].context.spanId;
    }
}

- (BOOL)pushActiveSpan:(SentrySpanId *)spanId
{
    id<SentrySpan> toActiveSpan;
    @synchronized(self.spans) {
        toActiveSpan = self.spans[spanId];
    }

    if (toActiveSpan == nil) {
        return NO;
    }

    @synchronized(self.activeSpanStack) {
        [self.activeSpanStack addObject:toActiveSpan];
    }
    return YES;
}

- (void)popActiveSpan
{
    @synchronized(self.activeSpanStack) {
        [self.activeSpanStack removeLastObject];
    }
}

- (void)finishSpan:(SentrySpanId *)spanId
{
    [self finishSpan:spanId withStatus:kSentrySpanStatusOk];
}

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status
{
    id<SentrySpan> spanTracker;
    @synchronized(self.spans) {
        spanTracker = self.spans[spanId];
        [self.spans removeObjectForKey:spanId];
    }

    [spanTracker finishWithStatus:status];
}

- (BOOL)isSpanAlive:(SentrySpanId *)spanId
{
    @synchronized(self.spans) {
        return self.spans[spanId] != nil;
    }
}

- (nullable id<SentrySpan>)getSpan:(SentrySpanId *)spanId
{
    @synchronized(self.spans) {
        return self.spans[spanId];
    }
}

@end

NS_ASSUME_NONNULL_END
