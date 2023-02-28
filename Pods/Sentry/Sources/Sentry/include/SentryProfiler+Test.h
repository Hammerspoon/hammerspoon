#include "SentryBacktrace.hpp"
#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
void processBacktrace(const sentry::profiling::Backtrace &backtrace,
    NSMutableDictionary<NSString *, NSMutableDictionary *> *threadMetadata,
    NSMutableDictionary<NSString *, NSDictionary *> *queueMetadata,
    NSMutableArray<NSDictionary<NSString *, id> *> *samples,
    NSMutableArray<NSMutableArray<NSNumber *> *> *stacks,
    NSMutableArray<NSDictionary<NSString *, id> *> *frames,
    NSMutableDictionary<NSString *, NSNumber *> *frameIndexLookup, uint64_t startTimestamp,
    NSMutableDictionary<NSString *, NSNumber *> *stackIndexLookup);
#endif
