#include "SentryProfilingConditionals.h"
#include "SentryThread.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface SentryThread ()

+ (SentryThread *)threadInfo;

@end

NS_ASSUME_NONNULL_END

#endif
