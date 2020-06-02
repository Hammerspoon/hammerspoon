#import "SentryDefines.h"
#import "SentryCrashReportSink.h"
#import "SentryCrashReportConverter.h"
#import "SentryClient.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryLog.h"
#import "SentryThread.h"
#import "SentryCrash.h"
#import "SentrySDK.h"

@implementation SentryCrashReportSink

- (void)handleConvertedEvent:(SentryEvent *)event report:(NSDictionary *)report sentReports:(NSMutableArray *)sentReports {
    [sentReports addObject:report];
    [SentrySDK captureEvent:event];
}

- (void)filterReports:(NSArray *)reports
          onCompletion:(SentryCrashReportFilterCompletion)onCompletion {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableArray *sentReports = [NSMutableArray new];
        for (NSDictionary *report in reports) {
            SentryCrashReportConverter *reportConverter = [[SentryCrashReportConverter alloc] initWithReport:report];
            if (nil != [SentrySDK.currentHub getClient]) {
                SentryEvent *event = [reportConverter convertReportToEvent];
                [self handleConvertedEvent:event report:report sentReports:sentReports];
            } else {
                [SentryLog logWithMessage:@"Crash reports were found but no [SentrySDK.currentHub getClient] is set. Cannot send crash reports to Sentry. This is probably a misconfiguration, make sure you set the client with [SentrySDK.currentHub bindClient] before calling startCrashHandlerWithError:." andLevel:kSentryLogLevelError];
            }
        }
        if (onCompletion) {
            onCompletion(sentReports, TRUE, nil);
        }
    });
}

@end
