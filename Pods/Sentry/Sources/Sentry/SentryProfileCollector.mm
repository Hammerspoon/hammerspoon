#import "SentryProfileCollector.h"
#import "SentryInternalDefines.h"
#import "SentrySDK+Private.h"
#import "SentryThreadHandle.hpp"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryProfilerSerialization.h"

@implementation SentryProfileCollector

+ (nullable NSMutableDictionary<NSString *, id> *)collectProfileBetween:(uint64_t)startSystemTime
                                                                    and:(uint64_t)endSystemTime
                                                               forTrace:(SentryId *)traceId
{
    NSMutableDictionary<NSString *, id> *payload = sentry_collectProfileDataHybridSDK(
        startSystemTime, endSystemTime, traceId, [SentrySDK currentHub]);

    if (payload != nil) {
        payload[@"platform"] = SentryPlatformName;
        payload[@"transaction"] = @{
            @"active_thread_id" :
                [NSNumber numberWithLongLong:sentry::profiling::ThreadHandle::current()->tid()]
        };
    }

    return payload;
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
