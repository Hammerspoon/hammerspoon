#import "SentryCrash.h"
#import "SentryDefines.h"

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashReportSink : NSObject <SentryCrashReportFilter>
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

@end

NS_ASSUME_NONNULL_END
