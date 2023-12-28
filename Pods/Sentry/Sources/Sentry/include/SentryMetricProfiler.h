#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyCPUUsage;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyCPUEnergyUsage;

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitBytes;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitPercentage;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitNanoJoules;

// The next two types are technically the same as far as the type system is concerned, but they
// actually contain different mixes of value types, so define them separately. If they ever change,
// the usage sites already specify which type each should be.

/**
 * A structure to hold a single metric reading and the time it was taken, as a dictionary with keyed
 * values either of type @c NSNumber for the reading value, or @c NSString for the timestamp (we
 * just encode @c uint64_t as a string since JSON doesn't officially support it).
 */
typedef NSDictionary<NSString *, id /* <NSNumber, NSString> */> SentrySerializedMetricReading;

/**
 * A structure containing the timeseries of values for a particular metric type, as a dictionary
 * with keyed values either of type @c NSString, for unit names, or an array of metrics entries
 * containing the values and timestamps in the above typedef.
 */
typedef NSDictionary<NSString *, id /* <NSString, NSArray<SentrySerializedMetricEntry *>> */>
    SentrySerializedMetricEntry;

/**
 * A profiler that gathers various time-series and event-based metrics on the app process, such as
 * CPU and memory usage timeseries and thermal and memory pressure warning notifications.
 */
@interface SentryMetricProfiler : NSObject

- (void)start;
/** Record a metrics sample. Helps ensure full metric coverage for concurrent spans. */
- (void)recordMetrics;
- (void)stop;

/**
 * Return a serialized dictionary of the collected metrics.
 * @discussion The dictionary will have the following structure:
 * @code
 * @"<metric-name>": @{
 *      @"unit": @"<unit-name>",
 *      @"values": @[
 *          @{
 *              @"elapsed_since_start_ns": @"<64-bit-unsigned-timestamp>",
 *              @"value": @"<numeric-value>"
 *          },
 *          // ... more dictionaries like that ...
 *      ]
 * }
 * @endcode
 */
- (NSMutableDictionary<NSString *, SentrySerializedMetricEntry *> *)
    serializeBetween:(uint64_t)startSystemTime
                 and:(uint64_t)endSystemTime;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
