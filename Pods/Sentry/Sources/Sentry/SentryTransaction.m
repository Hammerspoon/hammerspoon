#import "SentryTransaction.h"
#import "SentryEnvelopeItemType.h"

@implementation SentryTransaction {
    id<SentrySpan> _trace;
    NSArray<id<SentrySpan>> *_spans;
}

- (instancetype)initWithTrace:(id<SentrySpan>)trace children:(NSArray<id<SentrySpan>> *)children
{
    if ([super init]) {
        self.timestamp = trace.timestamp;
        self.startTimestamp = trace.startTimestamp;
        _trace = trace;
        _spans = children;
        self.type = SentryEnvelopeItemTypeTransaction;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *serializedData =
        [[NSMutableDictionary alloc] initWithDictionary:[super serialize]];

    NSMutableArray *spans = [[NSMutableArray alloc] init];
    for (id<SentrySpan> span in _spans) {
        [spans addObject:[span serialize]];
    }
    serializedData[@"spans"] = spans;

    NSMutableDictionary<NSString *, id> *mutableContext = [[NSMutableDictionary alloc] init];
    if (serializedData[@"contexts"] != nil) {
        [mutableContext addEntriesFromDictionary:serializedData[@"contexts"]];
    }
    mutableContext[@"trace"] = [_trace serialize];
    [serializedData setValue:mutableContext forKey:@"contexts"];

    return serializedData;
}
@end
