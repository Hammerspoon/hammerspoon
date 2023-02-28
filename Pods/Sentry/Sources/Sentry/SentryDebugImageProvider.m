#import "SentryDebugImageProvider.h"
#import "SentryCrashDefaultBinaryImageProvider.h"
#import "SentryCrashDynamicLinker.h"
#import "SentryCrashUUIDConversion.h"
#import "SentryDebugMeta.h"
#import "SentryFrame.h"
#import "SentryHexAddressFormatter.h"
#import "SentryInternalDefines.h"
#import "SentryLog.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import <Foundation/Foundation.h>

@interface
SentryDebugImageProvider ()

@property (nonatomic, strong) id<SentryCrashBinaryImageProvider> binaryImageProvider;
@end

@implementation SentryDebugImageProvider

- (instancetype)init
{
    SentryCrashDefaultBinaryImageProvider *provider =
        [[SentryCrashDefaultBinaryImageProvider alloc] init];

    self = [self initWithBinaryImageProvider:provider];

    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithBinaryImageProvider:(id<SentryCrashBinaryImageProvider>)binaryImageProvider
{
    if (self = [super init]) {
        self.binaryImageProvider = binaryImageProvider;
    }
    return self;
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForAddresses:(NSSet<NSString *> *)addresses
{
    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray array];

    NSArray<SentryDebugMeta *> *binaryImages = [self getDebugImages];

    for (SentryDebugMeta *sourceImage in binaryImages) {
        if ([addresses containsObject:sourceImage.imageAddress]) {
            [result addObject:sourceImage];
        }
    }

    return result;
}

- (void)extractDebugImageAddressFromFrames:(NSArray<SentryFrame *> *)frames
                                   intoSet:(NSMutableSet<NSString *> *)set
{
    for (SentryFrame *frame in frames) {
        if (frame.imageAddress) {
            [set addObject:frame.imageAddress];
        }
    }
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForFrames:(NSArray<SentryFrame *> *)frames
{
    NSMutableSet<NSString *> *imageAdresses = [[NSMutableSet alloc] init];
    [self extractDebugImageAddressFromFrames:frames intoSet:imageAdresses];
    return [self getDebugImagesForAddresses:imageAdresses];
}

- (NSArray<SentryDebugMeta *> *)getDebugImagesForThreads:(NSArray<SentryThread *> *)threads
{
    NSMutableSet<NSString *> *imageAdresses = [[NSMutableSet alloc] init];

    for (SentryThread *thread in threads) {
        [self extractDebugImageAddressFromFrames:thread.stacktrace.frames intoSet:imageAdresses];
    }

    return [self getDebugImagesForAddresses:imageAdresses];
}

- (NSArray<SentryDebugMeta *> *)getDebugImages
{
    NSMutableArray<SentryDebugMeta *> *debugMetaArray = [NSMutableArray new];

    NSInteger imageCount = [self.binaryImageProvider getImageCount];
    for (NSInteger i = 0; i < imageCount; i++) {
        SentryCrashBinaryImage image = [self.binaryImageProvider getBinaryImage:i];
        SentryDebugMeta *debugMeta = [self fillDebugMetaFrom:image];
        [debugMetaArray addObject:debugMeta];
    }

    return debugMetaArray;
}

- (SentryDebugMeta *)fillDebugMetaFrom:(SentryCrashBinaryImage)image
{
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
    debugMeta.debugID = [SentryDebugImageProvider convertUUID:image.uuid];
    debugMeta.type = SentryDebugImageType;

    if (image.vmAddress > 0) {
        NSNumber *imageVmAddress = [NSNumber numberWithUnsignedLongLong:image.vmAddress];
        debugMeta.imageVmAddress = sentry_formatHexAddress(imageVmAddress);
    }

    NSNumber *imageAddress = [NSNumber numberWithUnsignedLongLong:image.address];
    debugMeta.imageAddress = sentry_formatHexAddress(imageAddress);

    debugMeta.imageSize = @(image.size);

    if (nil != image.name) {
        debugMeta.codeFile = [[NSString alloc] initWithUTF8String:image.name];
    }

    return debugMeta;
}

+ (NSString *_Nullable)convertUUID:(const unsigned char *const)value
{
    if (nil == value) {
        return nil;
    }

    char uuidBuffer[37];
    sentrycrashdl_convertBinaryImageUUID(value, uuidBuffer);
    return [[NSString alloc] initWithCString:uuidBuffer encoding:NSASCIIStringEncoding];
}

@end
