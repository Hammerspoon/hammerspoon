#import "SentryCrash.h"
#import "SentryCrashInstallation.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryInAppLogic, SentryCrashWrapper, SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashInstallationReporter : SentryCrashInstallation
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

- (void)sendAllReportsWithCompletion:(nullable SentryCrashReportFilterCompletion)onCompletion;

@end

NS_ASSUME_NONNULL_END
