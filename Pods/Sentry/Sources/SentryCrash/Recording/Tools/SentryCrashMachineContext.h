// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMachineContext.h
//
//  Created by Karl Stenerud on 2016-12-02.
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

#ifndef HDR_SentryCrashMachineContext_h
#define HDR_SentryCrashMachineContext_h

#ifdef __cplusplus
extern "C" {
#endif

#include "SentryCrashThread.h"
#include <mach/mach.h>
#include <stdbool.h>

/** Suspend the runtime environment.
 */
void sentrycrashmc_suspendEnvironment(
    thread_act_array_t *suspendedThreads, mach_msg_type_number_t *numSuspendedThreads);

/**
 Suspend the runtime environment only if the amount of threads is not higher than
 maxSupportedThreads.
 */
void sentrycrashmc_suspendEnvironment_upToMaxSupportedThreads(thread_act_array_t *suspendedThreads,
    mach_msg_type_number_t *numSuspendedThreads, mach_msg_type_number_t maxSupportedThreads);

/** Resume the runtime environment.
 */
void sentrycrashmc_resumeEnvironment(thread_act_array_t threads, mach_msg_type_number_t numThreads);

/** Create a new machine context on the stack.
 * This macro creates a storage object on the stack, as well as a pointer of
 * type struct SentryCrashMachineContext* in the current scope, which points to
 * the storage object.
 *
 * Example usage: SentryCrashMC_NEW_CONTEXT(a_context);
 * This creates a new pointer at the current scope that behaves as if:
 *     struct SentryCrashMachineContext* a_context = some_storage_location;
 *
 * @param NAME The C identifier to give the pointer.
 */
#define SentryCrashMC_NEW_CONTEXT(NAME)                                                            \
    char sentrycrashmc_##NAME##_storage[sentrycrashmc_contextSize()];                              \
    struct SentryCrashMachineContext *NAME                                                         \
        = (struct SentryCrashMachineContext *)sentrycrashmc_##NAME##_storage

struct SentryCrashMachineContext;

/** Get the internal size of a machine context.
 */
int sentrycrashmc_contextSize(void);

/** Fill in a machine context from a thread.
 *
 * @param thread The thread to get information from.
 * @param destinationContext The context to fill.
 * @param isCrashedContext Used to indicate that this is the thread that
 * crashed,
 *
 * @return true if successful.
 */
bool sentrycrashmc_getContextForThread(SentryCrashThread thread,
    struct SentryCrashMachineContext *destinationContext, bool isCrashedContext);

/** Fill in a machine context from a signal handler.
 * A signal handler context is always assumed to be a crashed context.
 *
 * @param signalUserContext The signal context to get information from.
 * @param destinationContext The context to fill.
 *
 * @return true if successful.
 */
bool sentrycrashmc_getContextForSignal(
    void *signalUserContext, struct SentryCrashMachineContext *destinationContext);

/** Get the thread associated with a machine context.
 *
 * @param context The machine context.
 *
 * @return The associated thread.
 */
SentryCrashThread sentrycrashmc_getThreadFromContext(
    const struct SentryCrashMachineContext *const context);

/** Get the number of threads stored in a machine context.
 *
 * @param context The machine context.
 *
 * @return The number of threads.
 */
int sentrycrashmc_getThreadCount(const struct SentryCrashMachineContext *const context);

/** Get a thread from a machine context.
 *
 * @param context The machine context.
 * @param index The index of the thread to retrieve.
 *
 * @return The thread.
 */
SentryCrashThread sentrycrashmc_getThreadAtIndex(
    const struct SentryCrashMachineContext *const context, int index);

/** Get the index of a thread.
 *
 * @param context The machine context.
 * @param thread The thread.
 *
 * @return The thread's index, or -1 if it couldn't be determined.
 */
int sentrycrashmc_indexOfThread(
    const struct SentryCrashMachineContext *const context, SentryCrashThread thread);

/** Check if this is a crashed context.
 */
bool sentrycrashmc_isCrashedContext(const struct SentryCrashMachineContext *const context);

/** Check if this context can have stored CPU state.
 */
bool sentrycrashmc_canHaveCPUState(const struct SentryCrashMachineContext *const context);

/** Check if this context has valid exception registers.
 */
bool sentrycrashmc_hasValidExceptionRegisters(
    const struct SentryCrashMachineContext *const context);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMachineContext_h
