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

@end
