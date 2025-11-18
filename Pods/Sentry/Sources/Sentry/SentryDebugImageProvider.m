#import "SentryDebugImageProvider.h"
#import "SentryDebugImageProvider+HybridSDKs.h"
#if !SDK_V9
#    import "SentryCrashDefaultBinaryImageProvider.h"
#endif // !SDK_V9
#import "SentryCrashDynamicLinker.h"
#import "SentryCrashUUIDConversion.h"
#import "SentryDebugMeta.h"
#import "SentryDependencyContainer.h"
#import "SentryFormatter.h"
#import "SentryFrame.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugImageProvider ()

#if !SDK_V9
@property (nonatomic, strong) id<SentryCrashBinaryImageProvider> binaryImageProvider;
#endif // !SDK_V9
@property (nonatomic, strong) SentryBinaryImageCache *binaryImageCache;

@end

@implementation SentryDebugImageProvider

- (instancetype)init
{
#if SDK_V9
    self =
        [self initWithBinaryImageCache:SentryDependencyContainer.sharedInstance.binaryImageCache];
#else
    SentryCrashDefaultBinaryImageProvider *provider =
        [[SentryCrashDefaultBinaryImageProvider alloc] init];
    self = [self
        initWithBinaryImageProvider:provider
                   binaryImageCache:SentryDependencyContainer.sharedInstance.binaryImageCache];
#endif // SDK_V9

    return self;
}

/** Internal constructor for testing */
#if SDK_V9
- (instancetype)initWithBinaryImageCache:(SentryBinaryImageCache *)binaryImageCache
#else
- (instancetype)initWithBinaryImageProvider:(id<SentryCrashBinaryImageProvider>)binaryImageProvider
                           binaryImageCache:(SentryBinaryImageCache *)binaryImageCache
#endif // SDK_V9
{
    if (self = [super init]) {
#if !SDK_V9
        self.binaryImageProvider = binaryImageProvider;
#endif // !SDK_V9
        self.binaryImageCache = binaryImageCache;
    }
    return self;
}

- (void)extractDebugImageAddressFromFrames:(NSArray<SentryFrame *> *)frames
                                   intoSet:(NSMutableSet<NSString *> *)set
{
    for (SentryFrame *frame in frames) {
        if (frame.imageAddress) {
            [set addObject:SENTRY_UNWRAP_NULLABLE(NSString, frame.imageAddress)];
        }
    }
}

#if !SDK_V9

- (NSArray<SentryDebugMeta *> *)getDebugImagesForAddresses:(NSSet<NSString *> *)addresses
                                                   isCrash:(BOOL)isCrash
{
    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray array];

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray<SentryDebugMeta *> *binaryImages = [self getDebugImagesCrashed:isCrash];
#    pragma clang diagnostic pop

    for (SentryDebugMeta *sourceImage in binaryImages) {
        if (sourceImage.imageAddress &&
            [addresses containsObject:SENTRY_UNWRAP_NULLABLE(NSString, sourceImage.imageAddress)]) {
            [result addObject:sourceImage];
        }
    }

    return result;
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForFrames:(NSArray<SentryFrame *> *)frames
{
    // maintains previous behavior for the same method call by also trying to gather crash info
    return [self getDebugImagesForFrames:frames isCrash:YES];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForFrames:(NSArray<SentryFrame *> *)frames
                                                isCrash:(BOOL)isCrash
{
    NSMutableSet<NSString *> *imageAddresses = [[NSMutableSet alloc] init];
    [self extractDebugImageAddressFromFrames:frames intoSet:imageAddresses];
    return [self getDebugImagesForAddresses:imageAddresses isCrash:isCrash];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForThreads:(NSArray<SentryThread *> *)threads
{
    // maintains previous behavior for the same method call by also trying to gather crash info
    return [self getDebugImagesForThreads:threads isCrash:YES];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForThreads:(NSArray<SentryThread *> *)threads
                                                 isCrash:(BOOL)isCrash
{
    NSMutableSet<NSString *> *imageAddresses = [[NSMutableSet alloc] init];

    for (SentryThread *thread in threads) {
        NSArray<SentryFrame *> *_Nullable frames = thread.stacktrace.frames;
        if (frames != nil) {
            [self extractDebugImageAddressFromFrames:SENTRY_UNWRAP_NULLABLE(NSArray, frames)
                                             intoSet:imageAddresses];
        }
    }

    return [self getDebugImagesForAddresses:imageAddresses isCrash:isCrash];
}

- (NSArray<SentryDebugMeta *> *)getDebugImages
{
    // maintains previous behavior for the same method call by also trying to gather crash info
    return [self getDebugImagesCrashed:YES];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesCrashed:(BOOL)isCrash
{
    NSMutableArray<SentryDebugMeta *> *debugMetaArray = [NSMutableArray new];

    NSInteger imageCount = [self.binaryImageProvider getImageCount];
    for (NSInteger i = 0; i < imageCount; i++) {
        SentryCrashBinaryImage image = [self.binaryImageProvider getBinaryImage:i isCrash:isCrash];
        SentryDebugMeta *debugMeta = [self fillDebugMetaFrom:image];
        [debugMetaArray addObject:debugMeta];
    }

    return debugMetaArray;
}

#endif // !SDK_V9

- (NSArray<SentryDebugMeta *> *)getDebugImagesForImageAddressesFromCache:
    (NSSet<NSString *> *)imageAddresses
{
    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray array];

    for (NSString *imageAddress in imageAddresses) {
        const uint64_t imageAddressAsUInt64 = sentry_UInt64ForHexAddress(imageAddress);
        SentryBinaryImageInfo *info = [self.binaryImageCache imageByAddress:imageAddressAsUInt64];
        if (info == nil) {
            continue;
        }

        [result addObject:[self fillDebugMetaFromBinaryImageInfo:info]];
    }

    return result;
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForFrames:(NSArray<SentryFrame *> *)frames
{
    NSMutableSet<NSString *> *imageAddresses = [[NSMutableSet alloc] init];
    [self extractDebugImageAddressFromFrames:frames intoSet:imageAddresses];

    return [self getDebugImagesForImageAddressesFromCache:imageAddresses];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForThreads:(NSArray<SentryThread *> *)threads
{
    NSMutableSet<NSString *> *imageAddresses = [[NSMutableSet alloc] init];

    for (SentryThread *thread in threads) {
        NSArray<SentryFrame *> *_Nullable frames = thread.stacktrace.frames;
        if (frames != nil) {
            [self extractDebugImageAddressFromFrames:SENTRY_UNWRAP_NULLABLE(NSArray, frames)
                                             intoSet:imageAddresses];
        }
    }

    return [self getDebugImagesForImageAddressesFromCache:imageAddresses];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCache
{
    NSArray<SentryBinaryImageInfo *> *infos = [self.binaryImageCache getAllBinaryImages];
    NSMutableArray<SentryDebugMeta *> *result =
        [[NSMutableArray alloc] initWithCapacity:infos.count];
    for (SentryBinaryImageInfo *info in infos) {
        [result addObject:[self fillDebugMetaFromBinaryImageInfo:info]];
    }
    return result;
}

- (SentryDebugMeta *)fillDebugMetaFrom:(SentryCrashBinaryImage)image
{
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
    debugMeta.debugID = [SentryBinaryImageCache convertUUID:image.uuid];
    debugMeta.type = SentryDebugImageType;

    if (image.vmAddress > 0) {
        debugMeta.imageVmAddress = sentry_formatHexAddressUInt64(image.vmAddress);
    }

    debugMeta.imageAddress = sentry_formatHexAddressUInt64(image.address);

    debugMeta.imageSize = @(image.size);

    if (nil != image.name) {
        debugMeta.codeFile = [[NSString alloc] initWithUTF8String:image.name];
    }

    return debugMeta;
}

- (SentryDebugMeta *)fillDebugMetaFromBinaryImageInfo:(SentryBinaryImageInfo *)info
{
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
    debugMeta.debugID = info.uuid;
    debugMeta.type = SentryDebugImageType;

    if (info.vmAddress > 0) {
        debugMeta.imageVmAddress = sentry_formatHexAddressUInt64(info.vmAddress);
    }

    debugMeta.imageAddress = sentry_formatHexAddressUInt64(info.address);
    debugMeta.imageSize = @(info.size);
    debugMeta.codeFile = info.name;

    return debugMeta;
}

@end

NS_ASSUME_NONNULL_END
