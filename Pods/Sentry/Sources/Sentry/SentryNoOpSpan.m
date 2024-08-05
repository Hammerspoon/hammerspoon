#import "SentryNoOpSpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentrySwift.h"
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
        self.parentSpanId = nil;
        self.operation = @"";
        self.traceId = SentryId.empty;
        self.sampled = kSentrySampleDecisionUndecided;
        self.spanId = SentrySpanId.empty;
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

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value
{
}

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value unit:(SentryMeasurementUnit *)unit
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
    return [[SentryTraceHeader alloc] initWithTraceId:self.traceId
                                               spanId:self.spanId
                                              sampled:self.sampled];
}

- (NSDictionary *)serialize
{
    return @{};
}

@end

NS_ASSUME_NONNULL_END
