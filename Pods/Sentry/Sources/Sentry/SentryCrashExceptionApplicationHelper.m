#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#    import "SentryCrash.h"
#    import "SentryCrashExceptionApplication.h"
#    import "SentryCrashExceptionApplicationHelper.h"
#    import "SentryDependencyContainer.h"
#    import "SentrySDK+Private.h"
#    import "SentrySDK.h"

@implementation SentryCrashExceptionApplicationHelper

+ (void)reportException:(NSException *)exception
{
    SentryCrash *crash = SentryDependencyContainer.sharedInstance.crashReporter;
    if (nil != crash.uncaughtExceptionHandler && nil != exception) {
        crash.uncaughtExceptionHandler(exception);
    }
}

+ (void)_crashOnException:(NSException *)exception
{
    [SentrySDK captureCrashOnException:exception];
#    if !(SENTRY_TEST || SENTRY_TEST_CI)
    abort();
#    endif
}

@end

#endif // TARGET_OS_OSX
