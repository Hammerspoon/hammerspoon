#import "SentryCrashMachineContextWrapper.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryThread, SentryStacktraceBuilder;

NS_ASSUME_NONNULL_BEGIN

@interface SentryThreadInspector : NSObject
SENTRY_NO_INIT

- (id)initWithStacktraceBuilder:(SentryStacktraceBuilder *)stacktraceBuilder
       andMachineContextWrapper:(id<SentryCrashMachineContextWrapper>)machineContextWrapper;

- (NSArray<SentryThread *> *)getCurrentThreadsSkippingFrames:(NSInteger)framesToSkip;

@end

NS_ASSUME_NONNULL_END
