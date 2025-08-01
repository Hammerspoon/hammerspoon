#import "SentryCrash.h"
#import "SentryCrashInstallation.h"
#import "SentryDefines.h"

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashInstallationReporter : SentryCrashInstallation
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

- (void)sendAllReportsWithCompletion:(nullable SentryCrashReportFilterCompletion)onCompletion;

@end

NS_ASSUME_NONNULL_END
