#import "SentryMetricProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCurrentDateProvider.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchFactory.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryDispatchSourceWrapper.h"
#    import "SentryEvent+Private.h"
#    import "SentryFormatter.h"
#    import "SentryLog.h"
#    import "SentryNSTimerFactory.h"
#    import "SentrySystemWrapper.h"
#    import "SentryTime.h"
#    import "SentryTransaction.h"

/**
 * A storage class for metric readings, with one property for the reading value itself, whether it
 * be bytes of memory, % CPU etc, and another for the absolute system time it was recorded at.
 */
@interface SentryMetricReading : NSObject
@property (strong, nonatomic) NSNumber *value;
@property (assign, nonatomic) uint64_t absoluteTimestamp;
@end
@implementation SentryMetricReading
@end

NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint = @"memory_footprint";
NSString *const kSentryMetricProfilerSerializationKeyCPUUsage = @"cpu_usage";
NSString *const kSentryMetricProfilerSerializationKeyCPUEnergyUsage = @"cpu_energy_usage";

NSString *const kSentryMetricProfilerSerializationUnitBytes = @"byte";
NSString *const kSentryMetricProfilerSerializationUnitPercentage = @"percent";
NSString *const kSentryMetricProfilerSerializationUnitNanoJoules = @"nanojoule";

// Currently set to 10 Hz as we don't anticipate much utility out of a higher resolution when
// sampling CPU usage and memory footprint, and we want to minimize the overhead of making the
// necessary system calls to gather that information. This is currently roughly 10% of the
// backtrace profiler's resolution.
static uint64_t frequencyHz = 10;

namespace {
/**
 * @return a dictionary containing all the metric values recorded during the transaction, or @c nil
 * if there were no metrics recorded during the transaction.
 */
SentrySerializedMetricEntry *_Nullable serializeValuesWithNormalizedTime(
    NSArray<SentryMetricReading *> *absoluteTimestampValues, NSString *unit,
    uint64_t startSystemTime, uint64_t endSystemTime)
{
    const auto *timestampNormalizedValues = [NSMutableArray<SentrySerializedMetricReading *> array];
    [absoluteTimestampValues enumerateObjectsUsingBlock:^(
        SentryMetricReading *_Nonnull reading, NSUInteger idx, BOOL *_Nonnull stop) {
        // if the metric reading wasn't recorded until the transaction ended, don't include it
        if (!orderedChronologically(reading.absoluteTimestamp, endSystemTime)) {
            return;
        }

        // if the metric reading was taken before the transaction started, don't include it
        if (!orderedChronologically(startSystemTime, reading.absoluteTimestamp)) {
            return;
        }

        const auto relativeTimestamp = getDurationNs(startSystemTime, reading.absoluteTimestamp);

        [timestampNormalizedValues addObject:@ {
            @"elapsed_since_start_ns" : sentry_stringForUInt64(relativeTimestamp),
            @"value" : reading.value
        }];
    }];
    if (timestampNormalizedValues.count == 0) {
        return nil;
    }
    return @ { @"unit" : unit, @"values" : timestampNormalizedValues };
}
} // namespace

@implementation SentryMetricProfiler {
    SentryDispatchSourceWrapper *_dispatchSource;

    NSMutableArray<SentryMetricReading *> *_cpuUsage;
    NSMutableArray<SentryMetricReading *> *_memoryFootprint;

    NSNumber *previousEnergyReading;
    NSMutableArray<SentryMetricReading *> *_cpuEnergyUsage;
}

- (instancetype)init
{
    if (self = [super init]) {
        _cpuUsage = [NSMutableArray<SentryMetricReading *> array];
        _memoryFootprint = [NSMutableArray<SentryMetricReading *> array];
        _cpuEnergyUsage = [NSMutableArray<SentryMetricReading *> array];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#    pragma mark - Public

- (void)start
{
    [self registerSampler];
}

- (void)recordMetrics
{
    SENTRY_LOG_DEBUG(@"Recording profiling metrics sample");
    [self recordCPUsage];
    [self recordMemoryFootprint];
    [self recordEnergyUsageEstimate];
}

- (void)stop
{
    [_dispatchSource cancel];
}

- (NSMutableDictionary<NSString *, id> *)serializeBetween:(uint64_t)startSystemTime
                                                      and:(uint64_t)endSystemTime;
{
    NSArray<SentryMetricReading *> *memoryFootprint;
    NSArray<SentryMetricReading *> *cpuEnergyUsage;
    NSArray<SentryMetricReading *> *cpuUsage;
    @synchronized(self) {
        cpuEnergyUsage = [NSArray<SentryMetricReading *> arrayWithArray:_cpuEnergyUsage];
        memoryFootprint = [NSArray<SentryMetricReading *> arrayWithArray:_memoryFootprint];
        cpuUsage = [NSArray<SentryMetricReading *> arrayWithArray:_cpuUsage];
    }

    const auto dict = [NSMutableDictionary<NSString *, id> dictionary];
    if (memoryFootprint.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyMemoryFootprint]
            = serializeValuesWithNormalizedTime(memoryFootprint,
                kSentryMetricProfilerSerializationUnitBytes, startSystemTime, endSystemTime);
    }
    if (cpuEnergyUsage.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyCPUEnergyUsage]
            = serializeValuesWithNormalizedTime(cpuEnergyUsage,
                kSentryMetricProfilerSerializationUnitNanoJoules, startSystemTime, endSystemTime);
    }

    if (cpuUsage.count > 0) {
        dict[kSentryMetricProfilerSerializationKeyCPUUsage]
            = serializeValuesWithNormalizedTime(cpuUsage,
                kSentryMetricProfilerSerializationUnitPercentage, startSystemTime, endSystemTime);
    }

    return dict;
}

#    pragma mark - Private

- (void)registerSampler
{
    __weak auto weakSelf = self;
    const auto intervalNs = (uint64_t)1e9 / frequencyHz;
    const auto leewayNs = intervalNs / 2;
    _dispatchSource = [SentryDependencyContainer.sharedInstance.dispatchFactory
        sourceWithInterval:intervalNs
                    leeway:leewayNs
                 queueName:"io.sentry.metric-profiler"
                attributes:dispatch_queue_attr_make_with_qos_class(
                               DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0)
              eventHandler:^{ [weakSelf recordMetrics]; }];
}

- (void)recordMemoryFootprint
{
    NSError *error;
    const auto footprintBytes =
        [SentryDependencyContainer.sharedInstance.systemWrapper memoryFootprintBytes:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Failed to read memory footprint: %@", error);
        return;
    }

    @synchronized(self) {
        [_memoryFootprint addObject:[self metricReadingForValue:@(footprintBytes)]];
    }
}

- (void)recordCPUsage
{
    NSError *error;
    const auto result =
        [SentryDependencyContainer.sharedInstance.systemWrapper cpuUsageWithError:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Failed to read CPU usages: %@", error);
        return;
    }

    if (result == nil) {
        return;
    }

    @synchronized(self) {
        [_cpuUsage addObject:[self metricReadingForValue:result]];
    }
}

- (void)recordEnergyUsageEstimate
{
    NSError *error;
    const auto reading =
        [SentryDependencyContainer.sharedInstance.systemWrapper cpuEnergyUsageWithError:&error];
    if (error) {
        SENTRY_LOG_ERROR(@"Failed to read CPU energy usage: %@", error);
        return;
    }

    if (previousEnergyReading == nil) {
        previousEnergyReading = reading;
        return;
    }

    const auto value = reading.unsignedIntegerValue - previousEnergyReading.unsignedIntegerValue;
    previousEnergyReading = reading;

    @synchronized(self) {
        [_cpuEnergyUsage addObject:[self metricReadingForValue:@(value)]];
    }
}

- (SentryMetricReading *)metricReadingForValue:(NSNumber *)value
{
    const auto reading = [[SentryMetricReading alloc] init];
    reading.value = value;
    reading.absoluteTimestamp = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    return reading;
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
