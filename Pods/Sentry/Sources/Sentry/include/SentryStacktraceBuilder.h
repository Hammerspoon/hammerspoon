#import "SentryCrashMachineContext.h"
#import "SentryCrashStackCursor.h"
#include "SentryCrashThread.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryStacktrace, SentryFrameRemover, SentryCrashStackEntryMapper;

NS_ASSUME_NONNULL_BEGIN

/** Uses SentryCrash internally to retrieve the stacktrace.
 */
@interface SentryStacktraceBuilder : NSObject
SENTRY_NO_INIT

/**
 * Whether the stack trace frames should be fully symbolicated
 * or only contain instruction address and binary image.
 */
@property (nonatomic) BOOL symbolicate;

- (id)initWithCrashStackEntryMapper:(SentryCrashStackEntryMapper *)crashStackEntryMapper;

/**
 * Builds the stacktrace for the current thread using async safe functions, removing frames from the
 * SentrySDK until frames from a different package are found. When including Sentry via the Swift
 * Package Manager the package is the same as the application that includes Sentry. In this case the
 * full stacktrace is returned without skipping frames.
 */
- (SentryStacktrace *)buildStacktraceForCurrentThread;

/**
 * Retrieve the stacktrace for the current thread using native API, removing frames from the
 * SentrySDK until frames from a different package are found. When including Sentry via the Swift
 * Package Manager the package is the same as the application that includes Sentry. In this case the
 * full stacktrace is returned without skipping frames.
 * This function is not async safe but is faster then the 'buildStacktraceForCurrentThread'
 * alternative.
 */
- (nullable SentryStacktrace *)buildStacktraceForCurrentThreadAsyncUnsafe;

/**
 * Builds the stacktrace for given thread removing frames from the SentrySDK until frames from
 * a different package are found. When including Sentry via the Swift Package Manager the package is
 * the same as the application that includes Sentry. In this case the full stacktrace is returned
 * without skipping frames.
 */
- (SentryStacktrace *)buildStacktraceForThread:(SentryCrashThread)thread
                                       context:(struct SentryCrashMachineContext *)context;

- (SentryStacktrace *)buildStackTraceFromStackEntries:(SentryCrashStackEntry *)entries
                                               amount:(unsigned int)amount;
@end

NS_ASSUME_NONNULL_END
