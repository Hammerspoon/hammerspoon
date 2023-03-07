#import "SentryCrashExceptionApplication.h"
#import "SentryCrash.h"
#import "SentrySDK.h"

@implementation SentryCrashExceptionApplication

#if TARGET_OS_OSX

- (void)reportException:(NSException *)exception
{
    [[NSUserDefaults standardUserDefaults]
        registerDefaults:@{ @"NSApplicationCrashOnExceptions" : @YES }];
    if (nil != SentryCrash.sharedInstance.uncaughtExceptionHandler && nil != exception) {
        SentryCrash.sharedInstance.uncaughtExceptionHandler(exception);
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
