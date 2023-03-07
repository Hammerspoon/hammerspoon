#import "SentryNSProcessInfoWrapper.h"

@implementation SentryNSProcessInfoWrapper

- (NSString *)processDirectoryPath
{
    return NSBundle.mainBundle.bundlePath;
}

- (NSString *)processPath
{
    return NSBundle.mainBundle.executablePath;
}

- (NSUInteger)processorCount
{
    return NSProcessInfo.processInfo.processorCount;
}

@end
