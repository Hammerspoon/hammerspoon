// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashSysCtl.h
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

/* Convenience wrapper functions for sysctl calls.
 */

#ifndef HDR_SentryCrashSysCtl_h
#define HDR_SentryCrashSysCtl_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>
#include <sys/sysctl.h>

/** Get an int32 value via sysctl.
 *
 * @param major_cmd The major part of the command or name.
 *
 * @param minor_cmd The minor part of the command or name.
 *
 * @return The value returned by sysctl.
 */
int32_t sentrycrashsysctl_int32(int major_cmd, int minor_cmd);

/** Get an int32 value via sysctl by name.
 *
 * @param name The name of the command.
 *
 * @return The value returned by sysctl.
 */
int32_t sentrycrashsysctl_int32ForName(const char *name);

/** Get a uint32 value via sysctl.
 *
 * @param major_cmd The major part of the command or name.
 *
 * @param minor_cmd The minor part of the command or name.
 *
 * @return The value returned by sysctl.
 */
uint32_t sentrycrashsysctl_uint32(int major_cmd, int minor_cmd);

/** Get a uint32 value via sysctl by name.
 *
 * @param name The name of the command.
 *
 * @return The value returned by sysctl.
 */
uint32_t sentrycrashsysctl_uint32ForName(const char *name);

/** Get an int64 value via sysctl.
 *
 * @param major_cmd The major part of the command or name.
 *
 * @param minor_cmd The minor part of the command or name.
 *
 * @return The value returned by sysctl.
 */
int64_t sentrycrashsysctl_int64(int major_cmd, int minor_cmd);

/** Get an int64 value via sysctl by name.
 *
 * @param name The name of the command.
 *
 * @return The value returned by sysctl.
 */
int64_t sentrycrashsysctl_int64ForName(const char *name);

/** Get a uint64 value via sysctl.
 *
 * @param major_cmd The major part of the command or name.
 *
 * @param minor_cmd The minor part of the command or name.
 *
 * @return The value returned by sysctl.
 */
uint64_t sentrycrashsysctl_uint64(int major_cmd, int minor_cmd);

/** Get a uint64 value via sysctl by name.
 *
 * @param name The name of the command.
 *
 * @return The value returned by sysctl.
 */
uint64_t sentrycrashsysctl_uint64ForName(const char *name);

/** Get a string value via sysctl.
 *
 * @param major_cmd The major part of the command or name.
 *
 * @param minor_cmd The minor part of the command or name.
 *
 * @param value Pointer to a buffer to fill out. If NULL, does not fill
 *              anything out.
 *
 * @param maxSize The size of the buffer pointed to by value.
 *
 * @return The number of bytes written (or that would have been written if
 *         value is NULL).
 */
int sentrycrashsysctl_string(int major_cmd, int minor_cmd, char *value, int maxSize);

/** Get a string value via sysctl by name.
 *
 * @param name The name of the command.
 *
 * @param value Pointer to a buffer to fill out. If NULL, does not fill
 *              anything out.
 *
 * @param maxSize The size of the buffer pointed to by value.
 *
 * @return The number of bytes written (or that would have been written if
 *         value is NULL).
 */
int sentrycrashsysctl_stringForName(const char *name, char *value, int maxSize);

/** Get a timeval value via sysctl.
 *
 * @param major_cmd The major part of the command or name.
 *
 * @param minor_cmd The minor part of the command or name.
 *
 * @return The value returned by sysctl.
 */
struct timeval sentrycrashsysctl_timeval(int major_cmd, int minor_cmd);

/** Get a timeval value via sysctl by name.
 *
 * @param name The name of the command.
 *
 * @return The value returned by sysctl.
 */
struct timeval sentrycrashsysctl_timevalForName(const char *name);

struct timeval sentrycrashsysctl_currentProcessStartTime(void);

/** Get information about a process.
 *
 * @param pid The process ID.
 *
 * @param procInfo Struct to hold the proces information.
 *
 * @return true if the operation was successful.
 */
bool sentrycrashsysctl_getProcessInfo(int pid, struct kinfo_proc *procInfo);

/** Get the MAC address of the specified interface.
 * Note: As of iOS 7 this will always return a fixed value of 02:00:00:00:00:00.
 *
 * @param name Interface name (e.g. "en1").
 *
 * @param macAddressBuffer 6 bytes of storage to hold the MAC address.
 *
 * @return true if the address was successfully retrieved.
 */
bool sentrycrashsysctl_getMacAddress(const char *name, char *macAddressBuffer);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashSysCtl_h
