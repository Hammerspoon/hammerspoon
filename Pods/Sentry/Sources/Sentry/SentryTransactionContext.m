#import "SentryTransactionContext.h"
#import "SentryLogC.h"
#include "SentryProfilingConditionals.h"
#import "SentrySpanContext+Private.h"
#import "SentrySwift.h"
#import "SentryThread+Private.h"
#import "SentryThread.h"
#import "SentryTraceOrigin.h"
#import "SentryTransactionContext+Private.h"

NS_ASSUME_NONNULL_BEGIN

static const NSUInteger kSentryDefaultSamplingDecision = kSentrySampleDecisionUndecided;

@implementation SentryTransactionContext

#pragma mark - Public

- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation
{
    return [self initWithName:name
                    operation:operation
                      sampled:kSentrySampleDecisionUndecided
                   sampleRate:nil
                   sampleRand:nil];
}

- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
{
    return [self initWithName:name
                    operation:operation
                      sampled:sampled
                   sampleRate:nil
                   sampleRand:nil];
}

- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
{
    return [self initWithName:name
                   nameSource:kSentryTransactionNameSourceCustom
                    operation:operation
                       origin:SentryTraceOriginManual
                      sampled:sampled
                   sampleRate:sampleRate
                   sampleRand:sampleRand];
}

- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
{
    return [self initWithName:name
                   nameSource:kSentryTransactionNameSourceCustom
                    operation:operation
                       origin:SentryTraceOriginManual
                      traceId:traceId
                       spanId:spanId
                 parentSpanId:parentSpanId
                      sampled:kSentrySampleDecisionUndecided
                parentSampled:parentSampled
                   sampleRate:nil
             parentSampleRate:nil
                   sampleRand:nil
             parentSampleRand:nil];
}

- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand
{
    return [self initWithName:name
                   nameSource:kSentryTransactionNameSourceCustom
                    operation:operation
                       origin:SentryTraceOriginManual
                      traceId:traceId
                       spanId:spanId
                 parentSpanId:parentSpanId
                      sampled:kSentrySampleDecisionUndecided
                parentSampled:parentSampled
                   sampleRate:nil
             parentSampleRate:parentSampleRate
                   sampleRand:nil
             parentSampleRand:parentSampleRand];
}

#pragma mark - Private

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
{
    return [self initWithName:name
                   nameSource:source
                    operation:operation
                       origin:origin
                      sampled:kSentryDefaultSamplingDecision
                   sampleRate:nil
                   sampleRand:nil];
}

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
{
    if (self = [super initWithOperation:operation origin:origin sampled:sampled]) {
        [self commonInitWithName:name
                          source:source
                      sampleRate:sampleRate
                      sampleRand:sampleRand
                   parentSampled:kSentryDefaultSamplingDecision
                parentSampleRate:NULL
                parentSampleRand:NULL];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;
{
    if (self = [super initWithTraceId:traceId
                               spanId:spanId
                             parentId:parentSpanId
                            operation:operation
                      spanDescription:nil
                               origin:origin
                              sampled:kSentrySampleDecisionUndecided]) {
        [self commonInitWithName:name
                          source:source
                      sampleRate:nil
                      sampleRand:nil
                   parentSampled:parentSampled
                parentSampleRate:parentSampleRate
                parentSampleRand:parentSampleRand];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
                     sampled:(SentrySampleDecision)sampled
               parentSampled:(SentrySampleDecision)parentSampled
                  sampleRate:(nullable NSNumber *)sampleRate
            parentSampleRate:(nullable NSNumber *)parentSampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
            parentSampleRand:(nullable NSNumber *)parentSampleRand
{
    if (self = [super initWithTraceId:traceId
                               spanId:spanId
                             parentId:parentSpanId
                            operation:operation
                      spanDescription:nil
                               origin:origin
                              sampled:sampled]) {
        [self commonInitWithName:name
                          source:source
                      sampleRate:sampleRate
                      sampleRand:sampleRand
                   parentSampled:parentSampled
                parentSampleRate:parentSampleRate
                parentSampleRand:parentSampleRand];
    }
    return self;
}

- (void)getThreadInfo
{
#if SENTRY_TARGET_PROFILING_SUPPORTED
    self.threadInfo = [SentryThread threadInfo];
#endif
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (SentryThread *)sentry_threadInfo
{
    return self.threadInfo;
}
#endif

- (void)commonInitWithName:(NSString *)name
                    source:(SentryTransactionNameSource)source
                sampleRate:(nullable NSNumber *)sampleRate
                sampleRand:(nullable NSNumber *)sampleRand
             parentSampled:(SentrySampleDecision)parentSampled
          parentSampleRate:(nullable NSNumber *)parentSampleRate
          parentSampleRand:(nullable NSNumber *)parentSampleRand
{
    _name = [NSString stringWithString:name];
    _nameSource = source;
    self.sampleRate = sampleRate;
    self.sampleRand = sampleRand;
    self.parentSampled = parentSampled;
    self.parentSampleRate = parentSampleRate;
    self.parentSampleRand = parentSampleRand;
    [self getThreadInfo];
    SENTRY_LOG_DEBUG(@"Created transaction context with name %@", name);
}

@end

NS_ASSUME_NONNULL_END
