#import "SentrySwiftAsyncIntegration.h"
#import "SentryCrashStackCursor_SelfThread.h"

@implementation SentrySwiftAsyncIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    sentrycrashsc_setSwiftAsyncStitching(options.swiftAsyncStacktraces);
    return options.swiftAsyncStacktraces;
}

- (void)uninstall
{
    sentrycrashsc_setSwiftAsyncStitching(NO);
}

@end
