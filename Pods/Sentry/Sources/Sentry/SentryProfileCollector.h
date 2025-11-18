#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_TARGET_PROFILING_SUPPORTED

@interface SentryProfileCollector : NSObject

+ (nullable NSMutableDictionary<NSString *, id> *)collectProfileBetween:(uint64_t)startSystemTime
                                                                    and:(uint64_t)endSystemTime
                                                               forTrace:(SentryId *)traceId;

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_END
