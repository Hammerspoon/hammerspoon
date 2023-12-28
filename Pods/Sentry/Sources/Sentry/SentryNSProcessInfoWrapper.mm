#import "SentryNSProcessInfoWrapper.h"

@implementation SentryNSProcessInfoWrapper {
#if TEST
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
#endif

+ (SentryNSProcessInfoWrapper *)shared
{
    static SentryNSProcessInfoWrapper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

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

@end
