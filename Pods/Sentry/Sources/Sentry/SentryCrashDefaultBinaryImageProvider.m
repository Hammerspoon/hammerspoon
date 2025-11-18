#if !SDK_V9

#    import "SentryCrashDefaultBinaryImageProvider.h"
#    import "SentryCrashBinaryImageProvider.h"
#    import "SentryCrashDynamicLinker.h"
#    import <Foundation/Foundation.h>

@implementation SentryCrashDefaultBinaryImageProvider

- (NSInteger)getImageCount
{
    return sentrycrashdl_imageCount();
}

- (SentryCrashBinaryImage)getBinaryImage:(NSInteger)index isCrash:(BOOL)isCrash
{
    SentryCrashBinaryImage image = { 0 };
    sentrycrashdl_getBinaryImage((int)index, &image, isCrash);
    return image;
}

@end

#endif // !SDK_V9
