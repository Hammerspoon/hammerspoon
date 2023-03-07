#import "SentryCrash.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryInAppLogic, SentryCrashWrapper, SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashReportSink : NSObject <SentryCrashReportFilter>
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

@end

NS_ASSUME_NONNULL_END
