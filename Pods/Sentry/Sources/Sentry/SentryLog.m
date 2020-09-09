#import "SentryLog.h"
#import "SentryClient.h"
#import "SentrySDK.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLog

+ (void)logWithMessage:(NSString *)message andLevel:(SentryLogLevel)level
{
    SentryLogLevel defaultLevel = kSentryLogLevelError;
    if (SentrySDK.logLevel > 0) {
        defaultLevel = SentrySDK.logLevel;
    }
    if (level <= defaultLevel && level != kSentryLogLevelNone) {
        NSLog(@"Sentry - %@:: %@", [self.class logLevelToString:level], message);
    }
}

+ (NSString *)logLevelToString:(SentryLogLevel)level
{
    switch (level) {
    case kSentryLogLevelDebug:
        return @"Debug";
    case kSentryLogLevelVerbose:
        return @"Verbose";
    default:
        return @"Error";
    }
}
@end

NS_ASSUME_NONNULL_END
