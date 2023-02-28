#import "SentryProcessInfoWrapper.h"

@implementation SentryProcessInfoWrapper

- (NSString *)processDirectoryPath
{
    return NSBundle.mainBundle.bundlePath;
}

- (NSString *)processPath
{
    return NSBundle.mainBundle.executablePath;
}

@end
