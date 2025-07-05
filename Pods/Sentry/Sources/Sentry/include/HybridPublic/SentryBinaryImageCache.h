#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryBinaryImageInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, copy) NSString *UUID;
@property (nonatomic) uint64_t vmAddress;
@property (nonatomic) uint64_t address;
@property (nonatomic) uint64_t size;

@end

/**
 * This class listens to `SentryCrashBinaryImageCache` to keep a copy of the loaded binaries
 * information in a sorted collection that will be used to symbolicate frames with better
 * performance.
 */
@interface SentryBinaryImageCache : NSObject

- (void)start;

- (void)stop;

- (NSArray<SentryBinaryImageInfo *> *)getAllBinaryImages;

- (nullable SentryBinaryImageInfo *)imageByAddress:(const uint64_t)address;

- (NSSet<NSString *> *)imagePathsForInAppInclude:(NSString *)inAppInclude;

+ (NSString *_Nullable)convertUUID:(const unsigned char *const)value;

@end

NS_ASSUME_NONNULL_END
