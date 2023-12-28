#import "SentryPerformanceTracker.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySpan.h"
#import "SentrySpanId.h"
#import "SentrySpanProtocol.h"
#import "SentryTracer.h"
#import "SentryTransactionContext+Private.h"

#if SENTRY_HAS_UIKIT
#    import "SentryUIEventTracker.h"
#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface
SentryPerformanceTracker () <SentryTracerDelegate>

@property (nonatomic, strong) NSMutableDictionary<SentrySpanId *, id<SentrySpan>> *spans;
@property (nonatomic, strong) NSMutableArray<id<SentrySpan>> *activeSpanStack;

@end

@implementation SentryPerformanceTracker

+ (SentryPerformanceTracker *)shared
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

- (SentrySpanId *)startSpanWithName:(NSString *)name
                         nameSource:(SentryTransactionNameSource)source
                          operation:(NSString *)operation
                             origin:(NSString *)origin
{
    id<SentrySpan> activeSpan;
    @synchronized(self.activeSpanStack) {
        activeSpan = [self.activeSpanStack lastObject];
    }

    __block id<SentrySpan> newSpan;
    if (activeSpan != nil) {
        newSpan = [activeSpan startChildWithOperation:operation description:name];
        newSpan.origin = origin;
    } else {
        SentryTransactionContext *context = [[SentryTransactionContext alloc] initWithName:name
                                                                                nameSource:source
                                                                                 operation:operation
                                                                                    origin:origin];

        [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> span) {
            BOOL bindToScope = NO;
            if (span == nil) {
                bindToScope = YES;
            }
#if SENTRY_HAS_UIKIT
            else {
                if ([SentryUIEventTracker isUIEventOperation:span.operation]) {
                    SENTRY_LOG_DEBUG(
                        @"Cancelling previous UI event span %@", span.spanId.sentrySpanIdString);
                    [span finishWithStatus:kSentrySpanStatusCancelled];
                    bindToScope = YES;
                }
            }
#endif // SENTRY_HAS_UIKIT

            SENTRY_LOG_DEBUG(@"Creating new transaction bound to scope: %d", bindToScope);

            newSpan = [SentrySDK.currentHub
                startTransactionWithContext:context
                                bindToScope:bindToScope
                      customSamplingContext:@{}
                              configuration:[SentryTracerConfiguration configurationWithBlock:^(
                                                SentryTracerConfiguration *configuration) {
                                  configuration.waitForChildren = YES;
                              }]];

            [(SentryTracer *)newSpan setDelegate:self];
        }];
    }

    SentrySpanId *spanId = newSpan.spanId;

    if (spanId != nil) {
        @synchronized(self.spans) {
            self.spans[spanId] = newSpan;
        }
    } else {
        SENTRY_LOG_ERROR(@"startSpanWithName:operation: spanId is nil.");
        return [SentrySpanId empty];
    }

    return spanId;
}

- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                           inBlock:(void (^)(void))block
{
    SentrySpanId *spanId = [self startSpanWithName:description
                                        nameSource:source
                                         operation:operation
                                            origin:origin];
    SENTRY_LOG_DEBUG(@"Measuring span %@; description %@; operation: %@", spanId.sentrySpanIdString,
        description, operation);
    [self pushActiveSpan:spanId];
    block();
    [self popActiveSpan];
    [self finishSpan:spanId];
}

- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                      parentSpanId:(SentrySpanId *)parentSpanId
                           inBlock:(void (^)(void))block
{
    [self activateSpan:parentSpanId
           duringBlock:^{
               [self measureSpanWithDescription:description
                                     nameSource:source
                                      operation:operation
                                         origin:origin
                                        inBlock:block];
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
        return [self.activeSpanStack lastObject].spanId;
    }
}

- (BOOL)pushActiveSpan:(SentrySpanId *)spanId
{
    SENTRY_LOG_DEBUG(@"Pushing active span %@", spanId.sentrySpanIdString);
    id<SentrySpan> toActiveSpan;
    @synchronized(self.spans) {
        toActiveSpan = self.spans[spanId];
    }

    if (toActiveSpan == nil) {
        SENTRY_LOG_DEBUG(@"No span found with ID %@", spanId.sentrySpanIdString);
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
    SENTRY_LOG_DEBUG(@"Finishing performance span %@", spanId.sentrySpanIdString);
    [self finishSpan:spanId withStatus:kSentrySpanStatusOk];
}

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status
{
    id<SentrySpan> spanTracker;
    @synchronized(self.spans) {
        spanTracker = self.spans[spanId];
        // Hold reference for tracer until the tracer finishes because automatic
        // tracers aren't referenced by anything else.
        // callback to `tracerDidFinish` will release it.
        if (![spanTracker isKindOfClass:SentryTracer.self]) {
            [self.spans removeObjectForKey:spanId];
        }
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

- (nullable id<SentrySpan>)activeSpanForTracer:(SentryTracer *)tracer
{
    @synchronized(self.activeSpanStack) {
        return [self.activeSpanStack lastObject];
    }
}

- (void)clear
{
    [self.activeSpanStack removeAllObjects];
    [self.spans removeAllObjects];
}

- (void)tracerDidFinish:(SentryTracer *)tracer
{
    @synchronized(self.spans) {
        [self.spans removeObjectForKey:tracer.spanId];
    }
}

@end

NS_ASSUME_NONNULL_END
