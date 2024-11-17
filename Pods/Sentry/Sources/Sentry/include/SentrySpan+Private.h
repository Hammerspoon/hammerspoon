#import "SentrySpan.h"

#import "SentryProfilingConditionals.h"

@interface
SentrySpan ()

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (copy, nonatomic) NSString *_Nullable profileSessionID;
#endif //  SENTRY_TARGET_PROFILING_SUPPORTED

@end
