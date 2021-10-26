#import "SentrySpan.h"
#import "NSDate+SentryExtras.h"
#import "SentryCurrentDate.h"
#import "SentryNoOpSpan.h"
#import "SentryTraceHeader.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySpan ()
@end

@implementation SentrySpan {
    NSMutableDictionary<NSString *, id> *_data;
    NSMutableDictionary<NSString *, id> *_tags;
}

- (instancetype)initWithTransaction:(SentryTracer *)transaction context:(SentrySpanContext *)context
{
    if (self = [super init]) {
        _transaction = transaction;
        _context = context;
        self.startTimestamp = [SentryCurrentDate date];
        _data = [[NSMutableDictionary alloc] init];
        _tags = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
{
    return [self startChildWithOperation:operation description:nil];
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
{
    if (self.transaction == nil) {
        return [SentryNoOpSpan shared];
    }

    return [self.transaction startChildWithParentId:[self.context spanId]
                                          operation:operation
                                        description:description];
}

- (void)setDataValue:(nullable id)value forKey:(NSString *)key
{
    @synchronized(_data) {
        [_data setValue:value forKey:key];
    }
}

- (void)setExtraValue:(nullable id)value forKey:(NSString *)key
{
    [self setDataValue:value forKey:key];
}

- (void)removeDataForKey:(NSString *)key
{
    @synchronized(_data) {
        [_data removeObjectForKey:key];
    }
}

- (nullable NSDictionary<NSString *, id> *)data
{
    @synchronized(_data) {
        return [_data copy];
    }
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags setValue:value forKey:key];
    }
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(_tags) {
        [_tags removeObjectForKey:key];
    }
}

- (NSDictionary<NSString *, id> *)tags
{
    @synchronized(_tags) {
        return [_tags copy];
    }
}

- (BOOL)isFinished
{
    return self.timestamp != nil;
}

- (void)finish
{
    self.timestamp = [SentryCurrentDate date];
    if (self.transaction != nil) {
        [self.transaction spanFinished:self];
    }
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
    self.context.status = status;
    [self finish];
}

- (SentryTraceHeader *)toTraceHeader
{
    return [[SentryTraceHeader alloc] initWithTraceId:self.context.traceId
                                               spanId:self.context.spanId
                                              sampled:self.context.sampled];
}

- (NSDictionary *)serialize
{
    NSMutableDictionary<NSString *, id> *mutableDictionary =
        [[NSMutableDictionary alloc] initWithDictionary:[self.context serialize]];

    [mutableDictionary setValue:@(self.timestamp.timeIntervalSince1970) forKey:@"timestamp"];

    [mutableDictionary setValue:@(self.startTimestamp.timeIntervalSince1970)
                         forKey:@"start_timestamp"];

    @synchronized(_data) {
        if (_data.count > 0) {
            mutableDictionary[@"data"] = _data.copy;
        }
    }

    @synchronized(_tags) {
        if (_tags.count > 0) {
            NSMutableDictionary *tags = _context.tags.mutableCopy;
            [tags addEntriesFromDictionary:_tags.copy];
            mutableDictionary[@"tags"] = tags;
        }
    }

    return mutableDictionary;
}

@end

NS_ASSUME_NONNULL_END
