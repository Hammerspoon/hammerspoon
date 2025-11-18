#import "SentryTransaction.h"
#import "SentryEvent+Serialize.h"
#import "SentryInternalDefines.h"
#import "SentryNSDictionarySanitize.h"
#import "SentryProfilingConditionals.h"
#import "SentrySpan+Private.h"
#import "SentrySwift.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryTransaction

- (instancetype)initWithTrace:(SentryTracer *)trace children:(NSArray<id<SentrySpan>> *)children
{
    if (self = [super init]) {
        self.timestamp = trace.timestamp;
        self.startTimestamp = trace.startTimestamp;
        self.trace = trace;
        self.spans = children;
        self.type = SentryEnvelopeItemTypes.transaction;
    }
    return self;
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
    if (serializedData[@"contexts"] != nil &&
        [serializedData[@"contexts"] isKindOfClass:NSDictionary.class]) {
        [mutableContext addEntriesFromDictionary:SENTRY_UNWRAP_NULLABLE(
                                                     NSDictionary, serializedData[@"contexts"])];
    }

#if SENTRY_TARGET_PROFILING_SUPPORTED
    NSMutableDictionary *profileContextData = [NSMutableDictionary dictionary];
    profileContextData[@"profiler_id"] = self.trace.profileSessionID;
    mutableContext[@"profile"] = profileContextData;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    mutableContext[@"trace"] = [self.trace serialize];

    [serializedData setValue:mutableContext forKey:@"contexts"];

    NSMutableDictionary<NSString *, id> *traceTags = [sentry_sanitize(self.trace.tags) mutableCopy];

    // Adding tags from Trace to serializedData dictionary
    if (serializedData[@"tags"] != nil &&
        [serializedData[@"tags"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *tags = [NSMutableDictionary new];
        [tags
            addEntriesFromDictionary:SENTRY_UNWRAP_NULLABLE(NSDictionary, serializedData[@"tags"])];
        [tags addEntriesFromDictionary:traceTags];
        serializedData[@"tags"] = tags;
    } else {
        serializedData[@"tags"] = traceTags;
    }

    NSDictionary<NSString *, id> *traceData = sentry_sanitize(self.trace.data);

    // Adding data from Trace to serializedData dictionary
    if (serializedData[@"extra"] != nil &&
        [serializedData[@"extra"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *extra = [NSMutableDictionary new];
        [extra addEntriesFromDictionary:SENTRY_UNWRAP_NULLABLE(
                                            NSDictionary, serializedData[@"extra"])];
        [extra addEntriesFromDictionary:traceData];
        serializedData[@"extra"] = extra;
    } else {
        serializedData[@"extra"] = traceData;
    }

    if (self.trace.measurements.count > 0) {
        NSMutableDictionary<NSString *, id> *measurements = [NSMutableDictionary dictionary];

        for (NSString *measurementName in self.trace.measurements.allKeys) {
            measurements[measurementName] = [self.trace.measurements[measurementName] serialize];
        }

        serializedData[@"measurements"] = measurements;
    }

    if (self.trace) {
        serializedData[@"transaction"] = self.trace.transactionContext.name;

        serializedData[@"transaction_info"] =
            @{ @"source" : [self stringForNameSource:self.trace.transactionContext.nameSource] };
    }

    return serializedData;
}

- (NSString *)stringForNameSource:(SentryTransactionNameSource)source
{
    switch (source) {
    case kSentryTransactionNameSourceCustom:
        return @"custom";
    case kSentryTransactionNameSourceUrl:
        return @"url";
    case kSentryTransactionNameSourceRoute:
        return @"route";
    case kSentryTransactionNameSourceView:
        return @"view";
    case kSentryTransactionNameSourceComponent:
        return @"component";
    case kSentryTransactionNameSourceTask:
        return @"task";
    }
}
@end

NS_ASSUME_NONNULL_END
