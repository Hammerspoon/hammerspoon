#import "SentryTransaction.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryEnvelopeItemType.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransaction ()

@property (nonatomic, strong) NSArray<id<SentrySpan>> *spans;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *measurements;

@end

@implementation SentryTransaction

- (instancetype)initWithTrace:(id<SentrySpan>)trace children:(NSArray<id<SentrySpan>> *)children
{
    if (self = [super init]) {
        self.timestamp = trace.timestamp;
        self.startTimestamp = trace.startTimestamp;
        self.trace = trace;
        self.spans = children;
        self.type = SentryEnvelopeItemTypeTransaction;
        self.measurements = [NSMutableDictionary new];
    }
    return self;
}

- (void)setMeasurementValue:(id)value forKey:(NSString *)key
{
    self.measurements[key] = value;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *serializedData =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];

    NSMutableArray *serializedSpans = [[NSMutableArray alloc] init];
    for (id<SentrySpan> span in self.spans) {
        [serializedSpans addObject:[span serialize]];
    }
    serializedData[@"spans"] = serializedSpans;

    NSMutableDictionary<NSString *, id> *mutableContext = [[NSMutableDictionary alloc] init];
    if (serializedData[@"contexts"] != nil) {
        [mutableContext addEntriesFromDictionary:serializedData[@"contexts"]];
    }
    mutableContext[@"trace"] = [_trace serialize];
    [serializedData setValue:mutableContext forKey:@"contexts"];

    if (self.measurements.count > 0) {
        serializedData[@"measurements"] = [self.measurements.copy sentry_sanitize];
    }

    return serializedData;
}
@end

NS_ASSUME_NONNULL_END
