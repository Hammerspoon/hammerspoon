#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SentryProfilerMode) {
    SentryProfilerModeTrace,
    SentryProfilerModeContinuous,
};

typedef NS_ENUM(NSUInteger, SentryProfilerTruncationReason) {
    SentryProfilerTruncationReasonNormal,
    SentryProfilerTruncationReasonTimeout,
    SentryProfilerTruncationReasonAppMovedToBackground,
};

static NSTimeInterval kSentryProfilerChunkExpirationInterval = 10;
static NSTimeInterval kSentryProfilerTimeoutInterval = 30;

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
 * @note: For continuous profiling, this will only contain @c NSNumber values because we will store
 * timestamps as milliseconds, so we don't have to send them to the backend as @c NSString .
 */
typedef NSDictionary<NSString *, id /* <NSNumber, NSString> */> SentrySerializedMetricReading;

/**
 * A structure containing the timeseries of values for a particular metric type, as a dictionary
 * with keyed values either of type @c NSString, for unit names, or an array of metrics entries
 * containing the values and timestamps in the above typedef.
 */
typedef NSDictionary<NSString *, id /* <NSString, NSArray<SentrySerializedMetricEntry *>> */>
    SentrySerializedMetricEntry;

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
