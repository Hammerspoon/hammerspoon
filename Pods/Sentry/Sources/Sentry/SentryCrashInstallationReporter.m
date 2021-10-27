#import "SentryCrashInstallationReporter.h"
#import "SentryCrash.h"
#import "SentryCrashInstallation+Private.h"
#import "SentryCrashReportSink.h"
#import "SentryDefines.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryCrashInstallationReporter ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryCrashInstallationReporter

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
{
    if (self = [super initWithRequiredProperties:[NSArray new]]) {
        self.inAppLogic = inAppLogic;
    }
    return self;
}

- (id<SentryCrashReportFilter>)sink
{
    return [[SentryCrashReportSink alloc] initWithInAppLogic:self.inAppLogic];
}

- (void)sendAllReports
{
    [self sendAllReportsWithCompletion:NULL];
}

- (void)sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    [super
        sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
            if (nil != error) {
                [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLevelError];
            }
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Sent %lu crash report(s)",
                                                (unsigned long)filteredReports.count]
                             andLevel:kSentryLevelDebug];
            if (completed && onCompletion) {
                onCompletion(filteredReports, completed, error);
            }
        }];
}

@end

NS_ASSUME_NONNULL_END
