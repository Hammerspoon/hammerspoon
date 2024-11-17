// This file is also compiled into iOS-Swift-UITests and doesn't have access to private Sentry API
// there, so we add a few polyfills:
#if __has_include("SentryDefines.h")
#    import "SentryDefines.h"
#else
#    define SENTRY_HAS_UIKIT (TARGET_OS_IOS || TARGET_OS_TV)
#endif

#if __has_include("SentryLog.h")
#    import "SentryLog.h"
#else
#    define SENTRY_LOG_ERRNO(statement) statement
#    define SENTRY_LOG_DEBUG(...) NSLog(__VA_ARGS__)
#endif
// </polyfills>

#import "SentryDevice.h"
#import <sys/sysctl.h>
#if TARGET_OS_WATCH
#    import <WatchKit/WatchKit.h>
#endif

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif // SENTRY_HAS_UIKIT

namespace {
/**
 * @brief Get an iOS hardware model name, or for mac devices, either the hardware model name or CPU
 * architecture of the device, depending on the option provided.
 * @note For an iOS CPU architecture name, @c getArchitectureName must be used.
 * @discussion The values returned are different between iOS and macOS depending on which option is
 * provided. Some examples of values returned on different devices:
 * @code
 * | device                        | machine    | model          |
 * ---------------------------------------------------------------
 * | m1 mbp                        | arm64      | MacBookPro18,3 |
 * | iphone 13 mini                | iPhone14,4 | D16AP          |
 * | intel imac                    | x86_64     | iMac20,1       |
 * | iphone simulator on m1 mac    | arm64      | MacBookPro18,3 |
 * | iphone simulator on intel mac | x86_64     | iMac20,1       |
 * @endcode
 * @seealso See
 * https://www.cocoawithlove.com/blog/2016/03/08/swift-wrapper-for-sysctl.html#looking-for-the-source
 * for more info.
 * @return @c sysctl value for the combination of @c CTL_HW and the provided other flag in the
 * type parameter.
 */
NSString *
getHardwareDescription(int type)
{
#if SENTRY_HAS_UIKIT && !TARGET_OS_SIMULATOR
    NSCAssert(
        type != HW_MODEL, @"Don't call this method with HW_MODEL for (non-simulator) iOS devices");
#endif
    int mib[2];
    char name[128];
    size_t len;

    mib[0] = CTL_HW;
    mib[1] = type;
    len = sizeof(name);
    if (SENTRY_LOG_ERRNO(sysctl(mib, 2, &name, &len, NULL, 0)) != 0) {
        return @"";
    }

    const auto nameNSString = [NSString stringWithUTF8String:name];

    NSString *argName;
    switch (type) {
    case HW_PRODUCT:
        argName = @"HW_PRODUCT";
        break;
    case HW_MACHINE:
        argName = @"HW_MACHINE";
        break;
    case HW_MODEL:
        argName = @"HW_MODEL";
        break;
    default:
        NSCAssert(NO, @"Illegal argument");
    }

    SENTRY_LOG_DEBUG(@"Model name using %@: %@", argName, nameNSString);
    return nameNSString;
}

/**
 * Provided as a fallback in case @c sysctlbyname fails in @c sentry_getCPUArchitecture using the
 * @c hw.cpusubtype option.
 * @note I've not observed a device that has needed this (armcknight 22 Sep 2022). Tested on:
 * @code
 *   - 2015 MBP (x86_64h)
 *   - 2020 iMac (x86_64h)
 *   - 2021 MBP (M1 reported as arm64e)
 *   - iPhone simulators on all of those macs
 *   - iPhone 13 mini (arm64e)
 *   - iPod Touch (6th gen) (armv8)
 * @endcode
 */
NSString *
getCPUType(NSNumber *_Nullable subtype)
{
    cpu_type_t type;
    size_t typeSize = sizeof(type);
    if (SENTRY_LOG_ERRNO(sysctlbyname("hw.cputype", &type, &typeSize, NULL, 0)) != 0) {
        if (subtype != nil) {
            return
                [NSString stringWithFormat:@"no CPU type for unknown subtype %d", subtype.intValue];
        }
        return @"no CPU type or subtype";
    }
    switch (type) {
    default:
        if (subtype != nil) {
            return [NSMutableString
                stringWithFormat:@"unknown CPU type (%d) and subtype (%d)", type, subtype.intValue];
        }
        return [NSMutableString stringWithFormat:@"unknown CPU type (%d)", type];
    case CPU_TYPE_X86_64:
        // I haven't observed this branch being taken for 64-bit x86 architectures. Rather, the
        // x86 branch is taken, and then the subtype is reported as the 64-bit
        // subtype. Tested on a 2020 Intel-based iMac and 2015 MBP. (armcknight 21 Sep 2022)
        return @"x86_64";
    case CPU_TYPE_X86:
        return @"x86";
    case CPU_TYPE_ARM:
        return @"arm";
    case CPU_TYPE_ARM64:
        return @"arm64";
    case CPU_TYPE_ARM64_32:
        return @"arm64_32";
    }
}
} // namespace

NSString *
sentry_getCPUArchitecture(void)
{
    cpu_subtype_t subtype;
    size_t subtypeSize = sizeof(subtype);
    if (SENTRY_LOG_ERRNO(sysctlbyname("hw.cpusubtype", &subtype, &subtypeSize, NULL, 0)) != 0) {
        return getCPUType(nil);
    }
    switch (subtype) {
    default:
        return getCPUType(@(subtype));
    case CPU_SUBTYPE_X86_64_H:
        return @"x86_64h";
    case CPU_SUBTYPE_X86_64_ALL:
        return @"x86_64";
    case CPU_SUBTYPE_ARM_V6:
        return @"armv6";
    case CPU_SUBTYPE_ARM_V7:
        return @"armv7";
    case CPU_SUBTYPE_ARM_V7S:
        return @"armv7s";
    case CPU_SUBTYPE_ARM_V7K:
        return @"armv7k";
    case CPU_SUBTYPE_ARM64_V8:
        // this also catches CPU_SUBTYPE_ARM64_32_V8 since they are both defined as
        // ((cpu_subtype_t) 1)
        return @"armv8";
    case CPU_SUBTYPE_ARM64E:
        return @"arm64e";
    }
}

NSString *
sentry_getOSName(void)
{
#if TARGET_OS_MACCATALYST
    return @"Catalyst";
#elif SENTRY_HAS_UIKIT
    return [UIDevice currentDevice].systemName;
#else
    return @"macOS";
#endif // SENTRY_HAS_UIKIT
}

NSString *
sentry_getOSVersion(void)
{
#if TARGET_OS_WATCH
    // This function is only used for profiling, and profiling don't run for watchOS
    return @"";
#elif SENTRY_HAS_UIKIT
    return [UIDevice currentDevice].systemVersion;
#else
    const auto version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)version.majorVersion,
                     (long)version.minorVersion, (long)version.patchVersion];
#endif // SENTRY_HAS_UIKIT
}

NSString *
sentry_getDeviceModel(void)
{
#if TARGET_OS_SIMULATOR
    // iPhone/iPad, Watch and TV simulators
    const auto simulatedDeviceModelName = sentry_getSimulatorDeviceModel();
    SENTRY_LOG_DEBUG(@"Got simulated device model name %@ (running on %@)",
        simulatedDeviceModelName, getHardwareDescription(HW_MODEL));
    return simulatedDeviceModelName;
#else
#    if defined(HW_PRODUCT)
    if (@available(iOS 14, macOS 11, *)) {
        const auto model = getHardwareDescription(HW_PRODUCT);
        if (model.length > 0) {
            SENTRY_LOG_DEBUG(@"Model name using HW_PRODUCT: %@", model);
            return model;
        } else {
            SENTRY_LOG_DEBUG(@"Model name from HW_PRODUCT was empty.");
        }
    }
#    endif // defined(HW_PRODUCT)

#    if SENTRY_HAS_UIKIT
    // iPhone/iPad or TV devices
    return getHardwareDescription(HW_MACHINE);
#    else
    // macs and watch devices TODO: test on watch devices, may need to separate TARGET_OS_WATCH
    return getHardwareDescription(HW_MODEL);
#    endif // SENTRY_HAS_UIKIT
#endif // TARGET_OS_SIMULATOR
}

NSString *
sentry_getSimulatorDeviceModel(void)
{
    return NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"];
}

NSString *
sentry_getOSBuildNumber(void)
{
    char str[32];
    size_t size = sizeof(str);
    int cmd[2] = { CTL_KERN, KERN_OSVERSION };
    if (SENTRY_LOG_ERRNO(sysctl(cmd, sizeof(cmd) / sizeof(*cmd), str, &size, NULL, 0)) == 0) {
        return [NSString stringWithUTF8String:str];
    }
    return @"";
}

BOOL
sentry_isSimulatorBuild(void)
{
#if TARGET_OS_SIMULATOR
    return true;
#else
    return false;
#endif
}
