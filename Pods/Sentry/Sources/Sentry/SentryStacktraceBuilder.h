#import <Foundation/Foundation.h>

@class SentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/** Uses SentryCrash internally to retrieve the stacktrace.
 */
@interface SentryStacktraceBuilder : NSObject

- (SentryStacktrace *)buildStacktraceForCurrentThreadSkippingFrames:(NSInteger)framesToSkip
    NS_SWIFT_NAME(buildStacktraceForCurrentThread(framesToSkip:));

@end

NS_ASSUME_NONNULL_END
