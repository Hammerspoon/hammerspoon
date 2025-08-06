#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#    import "SentryCrash.h"
#    import "SentryDependencyContainer.h"
#    import "SentrySwizzle.h"
#    import "SentryUncaughtNSExceptions.h"
#    import <AppKit/NSApplication.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryUncaughtNSExceptions

+ (void)configureCrashOnExceptions
{
    [[NSUserDefaults standardUserDefaults]
        registerDefaults:@{ @"NSApplicationCrashOnExceptions" : @YES }];
}

+ (void)swizzleNSApplicationReportException
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    SEL selector = NSSelectorFromString(@"reportException:");
    SentrySwizzleInstanceMethod(NSApplication, selector, SentrySWReturnType(void),
        SentrySWArguments(NSException * exception), SentrySWReplacement({
            [SentryUncaughtNSExceptions capture:exception];
            return SentrySWCallOriginal(exception);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
}

+ (void)capture:(nullable NSException *)exception
{
    SentryCrash *crash = SentryDependencyContainer.sharedInstance.crashReporter;

    if (crash.uncaughtExceptionHandler == nil) {
        return;
    }

    if (exception == nil) {
        return;
    }

    crash.uncaughtExceptionHandler(exception);
}

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_OSX
