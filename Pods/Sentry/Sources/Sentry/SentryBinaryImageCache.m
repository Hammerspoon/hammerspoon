#import "SentryBinaryImageCache.h"
#import "SentryCrashBinaryImageCache.h"
#import "SentryDependencyContainer.h"
#import "SentryInAppLogic.h"
#import "SentryLog.h"

static void binaryImageWasAdded(const SentryCrashBinaryImage *image);

static void binaryImageWasRemoved(const SentryCrashBinaryImage *image);

@implementation SentryBinaryImageInfo
@end

@interface
SentryBinaryImageCache ()
@property (nonatomic, strong) NSMutableArray<SentryBinaryImageInfo *> *cache;
- (void)binaryImageAdded:(const SentryCrashBinaryImage *)image;
- (void)binaryImageRemoved:(const SentryCrashBinaryImage *)image;
@end

@implementation SentryBinaryImageCache

- (void)start
{
    @synchronized(self) {
        _cache = [NSMutableArray array];
        sentrycrashbic_registerAddedCallback(&binaryImageWasAdded);
        sentrycrashbic_registerRemovedCallback(&binaryImageWasRemoved);
    }
}

- (void)stop
{
    @synchronized(self) {
        sentrycrashbic_registerAddedCallback(NULL);
        sentrycrashbic_registerRemovedCallback(NULL);
        _cache = nil;
    }
}

- (void)binaryImageAdded:(const SentryCrashBinaryImage *)image
{
    if (image == NULL) {
        SENTRY_LOG_WARN(@"The image is NULL. Can't add NULL to cache.");
        return;
    }

    if (image->name == NULL) {
        SENTRY_LOG_WARN(@"The image name was NULL. Can't add image to cache.");
        return;
    }

    NSString *imageName = [NSString stringWithCString:image->name encoding:NSUTF8StringEncoding];

    if (imageName == nil) {
        SENTRY_LOG_WARN(@"Couldn't convert the cString image name to an NSString. This could be "
                        @"due to a different encoding than NSUTF8StringEncoding of the cString..");
        return;
    }

    SentryBinaryImageInfo *newImage = [[SentryBinaryImageInfo alloc] init];
    newImage.name = imageName;
    newImage.address = image->address;
    newImage.size = image->size;

    @synchronized(self) {
        NSUInteger left = 0;
        NSUInteger right = _cache.count;

        while (left < right) {
            NSUInteger mid = (left + right) / 2;
            SentryBinaryImageInfo *compareImage = _cache[mid];
            if (newImage.address < compareImage.address) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        [_cache insertObject:newImage atIndex:left];
    }
}

- (void)binaryImageRemoved:(const SentryCrashBinaryImage *)image
{
    if (image == NULL) {
        SENTRY_LOG_WARN(@"The image is NULL. Can't remove it from the cache.");
        return;
    }

    @synchronized(self) {
        NSInteger index = [self indexOfImage:image->address];
        if (index >= 0) {
            [_cache removeObjectAtIndex:index];
        }
    }
}

- (nullable SentryBinaryImageInfo *)imageByAddress:(const uint64_t)address;
{
    @synchronized(self) {
        NSInteger index = [self indexOfImage:address];
        return index >= 0 ? _cache[index] : nil;
    }
}

- (NSInteger)indexOfImage:(uint64_t)address
{
    if (_cache == nil)
        return -1;

    NSInteger left = 0;
    NSInteger right = _cache.count - 1;

    while (left <= right) {
        NSInteger mid = (left + right) / 2;
        SentryBinaryImageInfo *image = _cache[mid];

        if (address >= image.address && address < (image.address + image.size)) {
            return mid;
        } else if (address < image.address) {
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }

    return -1; // Address not found
}

- (nullable NSString *)pathForInAppInclude:(NSString *)inAppInclude
{
    @synchronized(self) {
        for (SentryBinaryImageInfo *info in _cache) {
            if ([SentryInAppLogic isImageNameInApp:info.name inAppInclude:inAppInclude]) {
                return info.name;
            }
        }
    }
    return nil;
}

@end

static void
binaryImageWasAdded(const SentryCrashBinaryImage *image)
{
    [SentryDependencyContainer.sharedInstance.binaryImageCache binaryImageAdded:image];
}

static void
binaryImageWasRemoved(const SentryCrashBinaryImage *image)
{
    [SentryDependencyContainer.sharedInstance.binaryImageCache binaryImageRemoved:image];
}
