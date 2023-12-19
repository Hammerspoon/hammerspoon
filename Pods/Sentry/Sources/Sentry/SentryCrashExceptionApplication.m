#import "SentryCrashExceptionApplication.h"
#import "SentryCrash.h"
#import "SentryDependencyContainer.h"
#import "SentrySDK.h"

@implementation SentryCrashExceptionApplication

#if TARGET_OS_OSX

- (void)reportException:(NSException *)exception
{
    [[NSUserDefaults standardUserDefaults]
        registerDefaults:@{ @"NSApplicationCrashOnExceptions" : @YES }];
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

#endif

@end
