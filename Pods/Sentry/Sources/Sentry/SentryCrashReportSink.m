#import "SentryCrashReportSink.h"
#import "SentryAttachment.h"
#import "SentryClient.h"
#import "SentryCrash.h"
#include "SentryCrashMonitor_AppState.h"
#import "SentryCrashReportConverter.h"
#import "SentryCrashWrapper.h"
#import "SentryDefines.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentrySDK.h"
#import "SentryScope+Private.h"
#import "SentryThread.h"

static const NSTimeInterval SENTRY_APP_START_CRASH_DURATION_THRESHOLD = 2.0;
static const NSTimeInterval SENTRY_APP_START_CRASH_FLUSH_DURATION = 5.0;

@interface
SentryCrashReportSink ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;

@end

@implementation SentryCrashReportSink

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
        self.crashWrapper = crashWrapper;
        self.dispatchQueue = dispatchQueue;
    }
    return self;
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSTimeInterval durationFromCrashStateInitToLastCrash
        = self.crashWrapper.durationFromCrashStateInitToLastCrash;
    if (durationFromCrashStateInitToLastCrash > 0
        && durationFromCrashStateInitToLastCrash <= SENTRY_APP_START_CRASH_DURATION_THRESHOLD) {
        SENTRY_LOG_WARN(@"Startup crash: detected.");
        [self sendReports:reports onCompletion:onCompletion];

        [SentrySDK flush:SENTRY_APP_START_CRASH_FLUSH_DURATION];
        SENTRY_LOG_DEBUG(@"Startup crash: Finished flushing.");

    } else {
        [self.dispatchQueue
            dispatchAsyncWithBlock:^{ [self sendReports:reports onCompletion:onCompletion]; }];
    }
}

- (void)sendReports:(NSArray *)reports onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *sentReports = [NSMutableArray new];
    for (NSDictionary *report in reports) {
        SentryCrashReportConverter *reportConverter =
            [[SentryCrashReportConverter alloc] initWithReport:report inAppLogic:self.inAppLogic];
        if (nil != [SentrySDK.currentHub getClient]) {
            SentryEvent *event = [reportConverter convertReportToEvent];
            if (nil != event) {
                [self handleConvertedEvent:event report:report sentReports:sentReports];
            }
        } else {
            SENTRY_LOG_ERROR(
                @"Crash reports were found but no [SentrySDK.currentHub getClient] is set. "
                @"Cannot send crash reports to Sentry. This is probably a misconfiguration, "
                @"make sure you set the client with [SentrySDK.currentHub bindClient] before "
                @"calling startCrashHandlerWithError:.");
        }
    }
    if (onCompletion) {
        onCompletion(sentReports, YES, nil);
    }
}

- (void)handleConvertedEvent:(SentryEvent *)event
                      report:(NSDictionary *)report
                 sentReports:(NSMutableArray *)sentReports
{
    [sentReports addObject:report];
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];

    if (report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM]) {
        for (NSString *ssPath in report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM]) {
            [scope addCrashReportAttachmentInPath:ssPath];
        }
    }

    [SentrySDK captureCrashEvent:event withScope:scope];
}

@end
