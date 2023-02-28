#import <Foundation/Foundation.h>

#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * This class is actually a DebugImage:
 * https://develop.sentry.dev/sdk/event-payloads/debugmeta/#debug-images and should be renamed to
 * SentryDebugImage in a future version.
 *
 * Contains information about a loaded library in the process and the memory address.
 *
 * @discussion Since 8.2.0, the SDK changed the debug image type from "apple" to "macho". For macho,
 * the SDK now sends ``debugID`` instead of ``uuid``, and ``codeFile`` instead of ``name``. For more
 * information check https://develop.sentry.dev/sdk/event-payloads/debugmeta/#mach-o-images.
 */
NS_SWIFT_NAME(DebugMeta)
@interface SentryDebugMeta : NSObject <SentrySerializable>

/**
 * The UUID of the image. Use ``debugID`` when using ``type`` "macho".
 */
@property (nonatomic, copy) NSString *_Nullable uuid;

/**
 * Identifier of the dynamic library or executable. It is the value of the LC_UUID load command in
 * the Mach header, formatted as UUID.
 */
@property (nonatomic, copy) NSString *_Nullable debugID;

/**
 * Type of debug meta. We highly recommend using "macho"; was "apple" previously.
 */
@property (nonatomic, copy) NSString *_Nullable type;

/**
 * Name of the image. Use ``codeFile`` when using ``type`` "macho".
 */
@property (nonatomic, copy) NSString *_Nullable name;

/**
 * The size of the image in virtual memory. If missing, Sentry will assume that the image spans up
 * to the next image, which might lead to invalid stack traces.
 */
@property (nonatomic, copy) NSNumber *_Nullable imageSize;

/**
 * Memory address, at which the image is mounted in the virtual address space of the process. Should
 * be a string in hex representation prefixed with "0x".
 */
@property (nonatomic, copy) NSString *_Nullable imageAddress;

/**
 * Preferred load address of the image in virtual memory, as declared in the headers of the image.
 * When loading an image, the operating system may still choose to place it at a different address.
 */
@property (nonatomic, copy) NSString *_Nullable imageVmAddress;

/**
 *
 */
@property (nonatomic, copy) NSString *_Nullable codeFile;

- (instancetype)init;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
