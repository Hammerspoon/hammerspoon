#import "SentryLog.h"
#import "SentryLevelMapper.h"
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

    if ([self willLogAtLevel:level]) {
        [logOutput log:[NSString stringWithFormat:@"[Sentry] [%@] %@", nameForSentryLevel(level),
                                 message]];
    }
}

+ (BOOL)willLogAtLevel:(SentryLevel)level
{
    return isDebug && level != kSentryLevelNone && level >= diagnosticLevel;
}

// Internal and only needed for testing.
+ (void)setLogOutput:(SentryLogOutput *)output
{
    logOutput = output;
}

// Internal and only needed for testing.
+ (SentryLogOutput *)logOutput
{
    return logOutput;
}

// Internal and only needed for testing.
+ (BOOL)isDebug
{
    return isDebug;
}

// Internal and only needed for testing.
+ (SentryLevel)diagnosticLevel
{
    return diagnosticLevel;
}

@end

NS_ASSUME_NONNULL_END
