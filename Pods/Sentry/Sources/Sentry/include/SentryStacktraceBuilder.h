#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryStacktrace, SentryFrameRemover, SentryCrashStackEntryMapper;

NS_ASSUME_NONNULL_BEGIN

/** Uses SentryCrash internally to retrieve the stacktrace.
 */
@interface SentryStacktraceBuilder : NSObject
SENTRY_NO_INIT

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper;

/**
 * Builds the stacktrace for the current thread removing frames from the SentrySDK until frames from
 * a different package are found. When including Sentry via the Swift Package Manager the package is
 * the same as the application that includes Sentry. In this case the full stacktrace is returned
 * without skipping frames.
 */
- (SentryStacktrace *)buildStacktraceForCurrentThread;

@end

NS_ASSUME_NONNULL_END
