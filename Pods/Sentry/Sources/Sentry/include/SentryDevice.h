#import <Foundation/Foundation.h>
/**
 * @seealso TargetConditionals.h has explanations and diagrams that show the relationships between
 * different @c TARGET_OS_... and @c TARGET_CPU_... macros.
 */

NS_ASSUME_NONNULL_BEGIN

/**
 * @return The CPU architecture name, such as @c armv7, @c arm64 or @c x86_64.
 */
NSString *sentry_getCPUArchitecture(void);

/**
 * @return The name of the operating system, such as @c iOS or @c macOS.
 */
NSString *sentry_getOSName(void);

/**
 * @return The OS version with up to three period-delimited numbers, like @c 14 , @c 14.0 or
 * @c 14.0.1 .
 */
NSString *sentry_getOSVersion(void);

/**
 * @return The Apple hardware descriptor, such as @c iPhone14,4 or @c MacBookPro10,8 .
 * @note If running on a simulator, this will be the model of the simulated device.
 */
NSString *sentry_getDeviceModel(void);

/**
 * @return The Apple hardware descriptor of the simulated device, such as @c iPhone14,4 or
 * @c MacBookPro10,8 .
 */
NSString *_Nullable sentry_getSimulatorDeviceModel(void);

/**
 * @return A string describing the OS version's specific build, with alphanumeric characters, like
 * @c 21G115 .
 */
NSString *sentry_getOSBuildNumber(void);

/**
 * @return @c YES if built and running in a simulator on a mac device, @c NO if running on a device.
 */
BOOL sentry_isSimulatorBuild(void);

NS_ASSUME_NONNULL_END
