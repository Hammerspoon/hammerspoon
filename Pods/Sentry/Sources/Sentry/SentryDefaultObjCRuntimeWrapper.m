#import "SentryDefaultObjCRuntimeWrapper.h"
#import <objc/runtime.h>

@implementation SentryDefaultObjCRuntimeWrapper

- (const char **)copyClassNamesForImage:(const char *)image amount:(unsigned int *)outCount
{
    return objc_copyClassNamesForImage(image, outCount);
}

- (const char *)class_getImageName:(Class)cls
{
    return class_getImageName(cls);
}

@end
