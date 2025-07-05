#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#    import "SentryCrashExceptionApplication.h"
#    import "SentryCrashExceptionApplicationHelper.h"
#    import "SentryUncaughtNSExceptions.h"

@implementation SentryCrashExceptionApplication

- (void)reportException:(NSException *)exception
{
    [SentryUncaughtNSExceptions configureCrashOnExceptions];
    // We cannot test an NSApplication because you create more than one at a time, so we use a
    // helper to hold the logic.
    [SentryCrashExceptionApplicationHelper reportException:exception];
    [super reportException:exception];
}

- (void)_crashOnException:(NSException *)exception
{
    [SentryCrashExceptionApplicationHelper _crashOnException:exception];
}

@end

#endif // TARGET_OS_OSX
