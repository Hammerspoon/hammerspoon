#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryNSProcessInfoWrapper;
@class SentryNSTimerWrapper;
@class SentrySystemWrapper;
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyCPUUsageFormat;

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitBytes;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitPercentage;

// The next two types are technically the same as far as the type system is concerned, but they
// actually contain different mixes of value types, so define them separately. If they ever change,
// the usage sites already specify which type each should be.

/**
 * A structure to hold a single metric reading and the time it was taken, as a dictionary with keyed
 * values either of type NSNumber for the reading value, or NSString for the timestamp (we just
 * encode @cuint64\_t as a string since JSON doesn't officially support it).
 */
typedef NSDictionary<NSString *, id /* <NSNumber, NSString> */> SentrySerializedMetricReading;

/**
 * A structure containing the timeseries of values for a particular metric type, as a dictionary
 * with keyed values either of type NSString, for unit names, or an array of metrics entries
 * containing the values and timestamps in the above typedef.
 */
typedef NSDictionary<NSString *, id /* <NSString, NSArray<SentrySerializedMetricEntry *>> */>
    SentrySerializedMetricEntry;

/**
 * A profiler that gathers various time-series and event-based metrics on the app process, such as
 * CPU and memory usage timeseries and thermal and memory pressure warning notifications.
 */
@interface SentryMetricProfiler : NSObject

- (instancetype)initWithProcessInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
                             systemWrapper:(SentrySystemWrapper *)systemWrapper
                              timerWrapper:(SentryNSTimerWrapper *)timerWrapper;
- (void)start;
- (void)stop;

/**
 * Return a serialized dictionary of the collected metrics.
 *
 * The dictionary will have the following structure:
 * @code
 * @"<metric-name>": @{
 *      @"unit": @"<unit-name>",
 *      @"values": @[
 *          @"elapsed_since_start_ns": @"<64-bit-unsigned-timestamp>",
 *          @"value": @"<numeric-value>"
 *      ]
 * }
 * @endcode
 */
- (NSMutableDictionary<NSString *, SentrySerializedMetricEntry *> *)serializeForTransaction:
    (SentryTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
