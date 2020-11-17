#import "SentryCrashMachineContextWrapper.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryThread, SentryStacktraceBuilder;

NS_ASSUME_NONNULL_BEGIN

@interface SentryThreadInspector : NSObject
SENTRY_NO_INIT

- (id)initWithStacktraceBuilder:(SentryStacktraceBuilder *)stacktraceBuilder
       andMachineContextWrapper:(id<SentryCrashMachineContextWrapper>)machineContextWrapper;

/**
 * Gets current threads with the stacktrace only for the current thread. Frames from the SentrySDK
 * are not included. For more details checkout SentryStacktraceBuilder.
 */
- (NSArray<SentryThread *> *)getCurrentThreads;

@end

NS_ASSUME_NONNULL_END
