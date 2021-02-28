#import "SentryCrash.h"
#import "SentryCrashInstallation.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryFrameInAppLogic;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashInstallationReporter : SentryCrashInstallation
SENTRY_NO_INIT

- (instancetype)initWithFrameInAppLogic:(SentryFrameInAppLogic *)frameInAppLogic;

- (void)sendAllReports;

@end

NS_ASSUME_NONNULL_END
