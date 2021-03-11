#import "SentryCrashReportSink.h"
#import "SentryClient.h"
#import "SentryCrash.h"
#import "SentryCrashReportConverter.h"
#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentrySDK.h"
#import "SentryThread.h"

@interface
SentryCrashReportSink ()

@property (nonatomic, strong) SentryFrameInAppLogic *frameInAppLogic;

@end

@implementation SentryCrashReportSink

- (instancetype)initWithFrameInAppLogic:(SentryFrameInAppLogic *)frameInAppLogic
{
    if (self = [super init]) {
        self.frameInAppLogic = frameInAppLogic;
    }
    return self;
}

- (void)handleConvertedEvent:(SentryEvent *)event
                      report:(NSDictionary *)report
                 sentReports:(NSMutableArray *)sentReports
{
    [sentReports addObject:report];
    [SentrySDK captureCrashEvent:event];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableArray *sentReports = [NSMutableArray new];
        for (NSDictionary *report in reports) {
            SentryCrashReportConverter *reportConverter =
                [[SentryCrashReportConverter alloc] initWithReport:report
                                                   frameInAppLogic:self.frameInAppLogic];
            if (nil != [SentrySDK.currentHub getClient]) {
                SentryEvent *event = [reportConverter convertReportToEvent];
                if (nil != event) {
                    [self handleConvertedEvent:event report:report sentReports:sentReports];
                }
            } else {
                [SentryLog logWithMessage:@"Crash reports were found but no "
                                          @"[SentrySDK.currentHub getClient] is set. Cannot send "
                                          @"crash reports to Sentry. This is probably a "
                                          @"misconfiguration, make sure you set the client with "
                                          @"[SentrySDK.currentHub bindClient] before calling "
                                          @"startCrashHandlerWithError:."
                                 andLevel:kSentryLevelError];
            }
        }
        if (onCompletion) {
            onCompletion(sentReports, TRUE, nil);
        }
    });
}

@end
