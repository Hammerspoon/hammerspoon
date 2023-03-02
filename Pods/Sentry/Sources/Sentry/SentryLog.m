#import "SentryLog.h"
#import "SentryLogOutput.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLog

/**
 * Enable per default to log initialization errors.
 */
static BOOL isDebug = YES;
static SentryLevel diagnosticLevel = kSentryLevelError;
static SentryLogOutput *logOutput;

+ (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level
{
    isDebug = debug;
    diagnosticLevel = level;
}

+ (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level
{
    if (nil == logOutput) {
        logOutput = [[SentryLogOutput alloc] init];
    }

    if (isDebug && level != kSentryLevelNone && level >= diagnosticLevel) {
        [logOutput
            log:[NSString stringWithFormat:@"Sentry - %@:: %@", SentryLevelNames[level], message]];
    }
}

/**
 * Internal and only needed for testing.
 */
+ (void)setLogOutput:(nullable SentryLogOutput *)output
{
    logOutput = output;
}

@end

NS_ASSUME_NONNULL_END
