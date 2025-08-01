#import "SentryNSProcessInfoWrapper.h"

@implementation SentryNSProcessInfoWrapper {
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
    NSString *_executablePath;
}
- (void)setProcessPath:(NSString *)path
{
    _executablePath = path;
}
#    define SENTRY_BINARY_EXECUTABLE_PATH _executablePath;

- (instancetype)init
{
    self = [super init];
    _executablePath = NSBundle.mainBundle.bundlePath;
    return self;
}

#else
}
#    define SENTRY_BINARY_EXECUTABLE_PATH NSBundle.mainBundle.executablePath;
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

- (NSString *)processDirectoryPath
{
    return NSBundle.mainBundle.bundlePath;
}

- (NSString *)processPath
{
    return SENTRY_BINARY_EXECUTABLE_PATH;
}

- (NSUInteger)processorCount
{
    return NSProcessInfo.processInfo.processorCount;
}

- (NSProcessInfoThermalState)thermalState
{
    return NSProcessInfo.processInfo.thermalState;
}

- (NSDictionary<NSString *, NSString *> *)environment
{
    return NSProcessInfo.processInfo.environment;
}

- (BOOL)iOSAppOnMac API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0))
{
    return NSProcessInfo.processInfo.isiOSAppOnMac;
}

- (BOOL)isMacCatalystApp API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0))
{
    return NSProcessInfo.processInfo.isMacCatalystApp;
}

@end
