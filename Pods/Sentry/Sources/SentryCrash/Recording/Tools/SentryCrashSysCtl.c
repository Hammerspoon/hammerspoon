// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashSysCtl.m
//
//  Created by Karl Stenerud on 2012-02-19.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "SentryCrashSysCtl.h"

// #define SentryCrashLogger_LocalLevel TRACE
#include "SentryCrashLogger.h"

#include <errno.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CHECK_SYSCTL_NAME(TYPE, CALL)                                                              \
    if (0 != (CALL)) {                                                                             \
        SentryCrashLOG_ERROR("Could not get %s value for %s: %s", #CALL, name, strerror(errno));   \
        return 0;                                                                                  \
    }

#define CHECK_SYSCTL_CMD(TYPE, CALL)                                                               \
    if (0 != (CALL)) {                                                                             \
        SentryCrashLOG_ERROR(                                                                      \
            "Could not get %s value for %d,%d: %s", #CALL, major_cmd, minor_cmd, strerror(errno)); \
        return 0;                                                                                  \
    }

int32_t
sentrycrashsysctl_int32(const int major_cmd, const int minor_cmd)
{
    int cmd[2] = { major_cmd, minor_cmd };
    int32_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_CMD(int32, sysctl(cmd, sizeof(cmd) / sizeof(*cmd), &value, &size, NULL, 0));

    return value;
}

int32_t
sentrycrashsysctl_int32ForName(const char *const name)
{
    int32_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_NAME(int32, sysctlbyname(name, &value, &size, NULL, 0));

    return value;
}

uint32_t
sentrycrashsysctl_uint32(const int major_cmd, const int minor_cmd)
{
    int cmd[2] = { major_cmd, minor_cmd };
    uint32_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_CMD(uint32, sysctl(cmd, sizeof(cmd) / sizeof(*cmd), &value, &size, NULL, 0));

    return value;
}

uint32_t
sentrycrashsysctl_uint32ForName(const char *const name)
{
    uint32_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_NAME(uint32, sysctlbyname(name, &value, &size, NULL, 0));

    return value;
}

int64_t
sentrycrashsysctl_int64(const int major_cmd, const int minor_cmd)
{
    int cmd[2] = { major_cmd, minor_cmd };
    int64_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_CMD(int64, sysctl(cmd, sizeof(cmd) / sizeof(*cmd), &value, &size, NULL, 0));

    return value;
}

int64_t
sentrycrashsysctl_int64ForName(const char *const name)
{
    int64_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_NAME(int64, sysctlbyname(name, &value, &size, NULL, 0));

    return value;
}

uint64_t
sentrycrashsysctl_uint64(const int major_cmd, const int minor_cmd)
{
    int cmd[2] = { major_cmd, minor_cmd };
    uint64_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_CMD(uint64, sysctl(cmd, sizeof(cmd) / sizeof(*cmd), &value, &size, NULL, 0));

    return value;
}

uint64_t
sentrycrashsysctl_uint64ForName(const char *const name)
{
    uint64_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_NAME(uint64, sysctlbyname(name, &value, &size, NULL, 0));

    return value;
}

int
sentrycrashsysctl_string(
    const int major_cmd, const int minor_cmd, char *const value, const int maxSize)
{
    int cmd[2] = { major_cmd, minor_cmd };
    size_t size = value == NULL ? 0 : (size_t)maxSize;

    CHECK_SYSCTL_CMD(string, sysctl(cmd, sizeof(cmd) / sizeof(*cmd), value, &size, NULL, 0));

    return (int)size;
}

int
sentrycrashsysctl_stringForName(const char *const name, char *const value, const int maxSize)
{
    size_t size = value == NULL ? 0 : (size_t)maxSize;

    CHECK_SYSCTL_NAME(string, sysctlbyname(name, value, &size, NULL, 0));

    return (int)size;
}

struct timeval
sentrycrashsysctl_timeval(const int major_cmd, const int minor_cmd)
{
    int cmd[2] = { major_cmd, minor_cmd };
    struct timeval value = { 0 };
    size_t size = sizeof(value);

    if (0 != sysctl(cmd, sizeof(cmd) / sizeof(*cmd), &value, &size, NULL, 0)) {
        SentryCrashLOG_ERROR(
            "Could not get timeval value for %d,%d: %s", major_cmd, minor_cmd, strerror(errno));
    }

    return value;
}

struct timeval
sentrycrashsysctl_timevalForName(const char *const name)
{
    struct timeval value = { 0 };
    size_t size = sizeof(value);

    if (0 != sysctlbyname(name, &value, &size, NULL, 0)) {
        SentryCrashLOG_ERROR("Could not get timeval value for %s: %s", name, strerror(errno));
    }

    return value;
}

struct timeval
sentrycrashsysctl_currentProcessStartTime(void)
{
    size_t len = 4;
    int mib[len];

    sysctlnametomib("kern.proc.pid", mib, &len);
    mib[3] = getpid();

    struct timeval value = { 0 };
    struct kinfo_proc kp;
    size_t kpSize = sizeof(kp);
    if (0 != sysctl(mib, 4, &kp, &kpSize, NULL, 0)) {
        SentryCrashLOG_ERROR("Could not get current process start time: %s", strerror(errno));
    } else {
        value = kp.kp_proc.p_un.__p_starttime;
    }

    return value;
}

bool
sentrycrashsysctl_getProcessInfo(const int pid, struct kinfo_proc *const procInfo)
{
    int cmd[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
    size_t size = sizeof(*procInfo);

    if (0 != sysctl(cmd, sizeof(cmd) / sizeof(*cmd), procInfo, &size, NULL, 0)) {
        SentryCrashLOG_ERROR("Could not get the name for process %d: %s", pid, strerror(errno));
        return false;
    }
    return true;
}

bool
sentrycrashsysctl_getMacAddress(const char *const name, char *const macAddressBuffer)
{
    // Based off
    // http://iphonedevelopertips.com/device/determine-mac-address.html

    int mib[6] = { CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, (int)if_nametoindex(name) };
    if (mib[5] == 0) {
        SentryCrashLOG_ERROR("Could not get interface index for %s: %s", name, strerror(errno));
        return false;
    }

    size_t length;
    if (sysctl(mib, 6, NULL, &length, NULL, 0) != 0) {
        SentryCrashLOG_ERROR("Could not get interface data for %s: %s", name, strerror(errno));
        return false;
    }

    void *ifBuffer = malloc(length);
    if (ifBuffer == NULL) {
        SentryCrashLOG_ERROR("Out of memory");
        return false;
    }

    if (sysctl(mib, 6, ifBuffer, &length, NULL, 0) != 0) {
        SentryCrashLOG_ERROR("Could not get interface data for %s: %s", name, strerror(errno));
        free(ifBuffer);
        return false;
    }

    struct if_msghdr *msgHdr = (struct if_msghdr *)ifBuffer;
    struct sockaddr_dl *sockaddr = (struct sockaddr_dl *)&msgHdr[1];
    memcpy(macAddressBuffer, LLADDR(sockaddr), 6);

    free(ifBuffer);

    return true;
}
