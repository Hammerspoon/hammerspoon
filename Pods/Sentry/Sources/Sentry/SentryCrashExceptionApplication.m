#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#    import "SentryCrash.h"
#    import "SentryCrashExceptionApplication.h"
#    import "SentryDependencyContainer.h"
#    import "SentrySDK.h"
#    import "SentryUncaughtNSExceptions.h"

@implementation SentryCrashExceptionApplication

- (void)reportException:(NSException *)exception
{
    [SentryUncaughtNSExceptions configureCrashOnExceptions];
    SentryCrash *crash = SentryDependencyContainer.sharedInstance.crashReporter;
    if (nil != crash.uncaughtExceptionHandler && nil != exception) {
        crash.uncaughtExceptionHandler(exception);
    }
    [super reportException:exception];
}

- (void)_crashOnException:(NSException *)exception
{
    [SentrySDK captureException:exception];
    abort();
}

@end

#endif // TARGET_OS_OSX
