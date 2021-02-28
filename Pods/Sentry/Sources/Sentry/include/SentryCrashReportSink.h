#import "SentryCrash.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryFrameInAppLogic;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashReportSink : NSObject <SentryCrashReportFilter>
SENTRY_NO_INIT

- (instancetype)initWithFrameInAppLogic:(SentryFrameInAppLogic *)frameInAppLogic;

@end

NS_ASSUME_NONNULL_END
