#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryMemoryPressureNotification)(uintptr_t);

/**
 * @c mach_vm_size_t Is a type defined in mach headers as an unsigned 64-bit type used to express
 * the amount of working memory the process currently has allocated.
 */
typedef mach_vm_size_t SentryRAMBytes;

/**
 * A wrapper around low-level system APIs that are found in headers such as @c <sys/...> and
 * @c <mach/...>.
 */
@interface SentrySystemWrapper : NSObject

- (SentryRAMBytes)memoryFootprintBytes:(NSError **)error;

/**
 * @return The CPU usage per core, where the order of results corresponds to the core number as
 * returned by the underlying system call, e.g. @c @[ @c <core-0-CPU-usage>, @c <core-1-CPU-usage>,
 * @c ...] .
 */
- (nullable NSNumber *)cpuUsageWithError:(NSError **)error;

/**
 * @return The cumulative amount of nanojoules expended by the CPU for this task since process
 * start.
 */
- (nullable NSNumber *)cpuEnergyUsageWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
