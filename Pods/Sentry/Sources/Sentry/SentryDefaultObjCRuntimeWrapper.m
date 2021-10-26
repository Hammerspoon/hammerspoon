#import "SentryDefaultObjCRuntimeWrapper.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@implementation SentryDefaultObjCRuntimeWrapper

- (int)getClassList:(__unsafe_unretained Class *)buffer bufferCount:(int)bufferCount
{
    return objc_getClassList(buffer, bufferCount);
}

@end
