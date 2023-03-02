#import "SentryNoOpSpan.h"
#import "SentryId.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTraceHeader.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryNoOpSpan

+ (instancetype)shared
{
    static SentryNoOpSpan *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _context = [[SentrySpanContext alloc] initWithTraceId:SentryId.empty
                                                       spanId:SentrySpanId.empty
                                                     parentId:nil
                                                    operation:@""
                                                      sampled:kSentrySampleDecisionUndecided];
    }
    return self;
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
{
    return [SentryNoOpSpan shared];
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
{
    return [SentryNoOpSpan shared];
}

- (void)setDataValue:(nullable id)value forKey:(NSString *)key
{
}

- (void)setExtraValue:(nullable id)value forKey:(NSString *)key
{
}

- (void)removeDataForKey:(NSString *)key
{
}

- (nullable NSDictionary<NSString *, id> *)data
{
    return nil;
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
}

- (void)removeTagForKey:(NSString *)key
{
}

- (NSDictionary<NSString *, id> *)tags
{
    return @{};
}

- (BOOL)isFinished
{
    return NO;
}

- (void)finish
{
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
}

- (SentryTraceHeader *)toTraceHeader
{
    return [[SentryTraceHeader alloc] initWithTraceId:self.context.traceId
                                               spanId:self.context.spanId
                                              sampled:self.context.sampled];
}

- (NSDictionary *)serialize
{
    return @{};
}

@end

NS_ASSUME_NONNULL_END
