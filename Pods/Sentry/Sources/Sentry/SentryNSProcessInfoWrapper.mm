#import "SentryNSProcessInfoWrapper.h"

@implementation SentryNSProcessInfoWrapper

- (NSUInteger)processorCount
{
    return NSProcessInfo.processInfo.processorCount;
}

@end
