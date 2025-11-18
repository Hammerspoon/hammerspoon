#import "SentrySystemWrapper.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDependencyContainer.h"
#    import "SentryError.h"
#    import <mach/mach.h>
#    include <thread>

@implementation SentrySystemWrapper {
    float processorCount;
}

- (instancetype)initWithProcessorCount:(long)count
{
    if ((self = [super init])) {
        processorCount = count;
    }
    return self;
}

- (SentryRAMBytes)memoryFootprintBytes:(NSError *__autoreleasing _Nullable *)error
{
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;

    const auto status = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
    if (status != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_info reported an error.", status);
        }
        return 0;
    }

    SentryRAMBytes footprintBytes;
    if (count >= TASK_VM_INFO_REV1_COUNT) {
        footprintBytes = info.phys_footprint;
    } else {
        footprintBytes = info.resident_size;
    }

    return footprintBytes;
}

- (NSNumber *)cpuUsageWithError:(NSError **)error
{
    mach_msg_type_number_t count;
    thread_act_array_t list;

    const auto taskThreadsStatus = task_threads(mach_task_self(), &list, &count);
    if (taskThreadsStatus != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"task_threads reported an error.", taskThreadsStatus);
        }
        vm_deallocate(
            mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);
        return nil;
    }

    auto usage = 0.f;
    for (decltype(count) i = 0; i < count; i++) {
        const auto thread = list[i];

        mach_msg_type_number_t infoSize = THREAD_BASIC_INFO_COUNT;
        thread_basic_info_data_t data;
        const auto threadInfoStatus = thread_info(
            thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&data), &infoSize);
        if (threadInfoStatus != KERN_SUCCESS) {
            if (error) {
                *error = NSErrorFromSentryErrorWithKernelError(
                    kSentryErrorKernel, @"task_threads reported an error.", threadInfoStatus);
            }
            vm_deallocate(
                mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);
            return nil;
        }

        usage += data.cpu_usage / processorCount;
    }

    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(list), sizeof(*list) * count);

    return @(usage);
}

// Only these architectures support `task_energy`
#    if defined(__arm__) || defined(__arm64__)
- (NSNumber *)cpuEnergyUsageWithError:(NSError **)error
{
    struct task_power_info_v2 powerInfo;

    mach_msg_type_number_t size = TASK_POWER_INFO_V2_COUNT;

    task_t task = mach_task_self();
    kern_return_t kr = task_info(task, TASK_POWER_INFO_V2, (task_info_t)&powerInfo, &size);
    if (kr != KERN_SUCCESS) {
        if (error) {
            *error = NSErrorFromSentryErrorWithKernelError(
                kSentryErrorKernel, @"Error with task_info(…TASK_POWER_INFO_V2…).", kr);
            ;
        }
    }
    return @(powerInfo.task_energy);
}
#    endif

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
