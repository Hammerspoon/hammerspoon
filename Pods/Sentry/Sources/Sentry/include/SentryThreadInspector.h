#import "SentryCrashMachineContextWrapper.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryThread, SentryStacktraceBuilder, SentryStacktrace, SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryThreadInspector : NSObject
SENTRY_NO_INIT

- (id)initWithStacktraceBuilder:(SentryStacktraceBuilder *)stacktraceBuilder
       andMachineContextWrapper:(id<SentryCrashMachineContextWrapper>)machineContextWrapper
                    symbolicate:(BOOL)symbolicate;

- (instancetype)initWithOptions:(SentryOptions *)options;

- (nullable SentryStacktrace *)stacktraceForCurrentThreadAsyncUnsafe;

/**
 * Gets current threads with the stacktrace only for the current thread. Frames from the SentrySDK
 * are not included. For more details checkout SentryStacktraceBuilder.
 * The first thread in the result is always the main thread.
 */
- (NSArray<SentryThread *> *)getCurrentThreads;

/**
 * Gets current threads with stacktrace,
 * this will pause every thread in order to be possible to retrieve this information.
 * Frames from the SentrySDK are not included. For more details checkout SentryStacktraceBuilder.
 * The first thread in the result is always the main thread.
 */
- (NSArray<SentryThread *> *)getCurrentThreadsWithStackTrace;

- (nullable NSString *)getThreadName:(SentryCrashThread)thread;

@end

NS_ASSUME_NONNULL_END
