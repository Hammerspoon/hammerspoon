#import "SentryCrashWrapper.h"
#import "SentryCrash.h"
#import "SentryCrashBinaryImageCache.h"
#import "SentryCrashMonitor_AppState.h"
#import "SentryCrashMonitor_System.h"
#import <Foundation/Foundation.h>
#import <SentryCrashCachedData.h>
#import <SentryCrashDebug.h>
#import <SentryCrashMonitor_System.h>
#import <SentryDependencyContainer.h>
#include <mach/mach.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryCrashWrapper

+ (instancetype)sharedInstance
{
    static SentryCrashWrapper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (BOOL)crashedLastLaunch
{
    return SentryDependencyContainer.sharedInstance.crashReporter.crashedLastLaunch;
}

- (NSTimeInterval)durationFromCrashStateInitToLastCrash
{
    return sentrycrashstate_currentState()->durationFromCrashStateInitToLastCrash;
}

- (NSTimeInterval)activeDurationSinceLastCrash
{
    return SentryDependencyContainer.sharedInstance.crashReporter.activeDurationSinceLastCrash;
}

- (BOOL)isBeingTraced
{
    return sentrycrashdebug_isBeingTraced();
}

- (BOOL)isSimulatorBuild
{
    return sentrycrash_isSimulatorBuild();
}

- (BOOL)isApplicationInForeground
{
    return sentrycrashstate_currentState()->applicationIsInForeground;
}

- (NSDictionary *)systemInfo
{
    static NSDictionary *sharedInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
        ^{ sharedInfo = SentryDependencyContainer.sharedInstance.crashReporter.systemInfo; });
    return sharedInfo;
}

- (bytes)freeMemorySize
{
    return sentrycrashcm_system_freememory_size();
}

- (bytes)freeStorageSize
{
    return sentrycrashcm_system_freestorage_size();
}

- (bytes)appMemorySize
{
    task_vm_info_data_t info;
    mach_msg_type_number_t size = TASK_VM_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.internal + info.compressed;
    }

    return 0;
}

- (void)startBinaryImageCache
{
    sentrycrashbic_startCache();
}

- (void)stopBinaryImageCache
{
    sentrycrashbic_stopCache();
}

@end

NS_ASSUME_NONNULL_END
