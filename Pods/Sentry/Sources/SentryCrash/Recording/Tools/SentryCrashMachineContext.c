// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMachineContext.c
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

#include "SentryCrashMachineContext.h"
#include "SentryCrashCPU.h"
#include "SentryCrashCPU_Apple.h"
#include "SentryCrashMachineContext_Apple.h"
#include "SentryCrashMonitor_MachException.h"
#include "SentryCrashStackCursor_MachineContext.h"
#include "SentryInternalCDefines.h"

#include <mach/mach.h>

#include "SentryAsyncSafeLog.h"

#ifdef __arm64__
#    define UC_MCONTEXT uc_mcontext64
typedef ucontext64_t SignalUserContext;
#else
#    define UC_MCONTEXT uc_mcontext
typedef ucontext_t SignalUserContext;
#endif

static inline bool
isStackOverflow(const SentryCrashMachineContext *const context)
{
    SentryCrashStackCursor stackCursor;
    sentrycrashsc_initWithMachineContext(
        &stackCursor, SentryCrashSC_STACK_OVERFLOW_THRESHOLD, context);
    while (stackCursor.advanceCursor(&stackCursor)) { }
    bool rv = stackCursor.state.hasGivenUp;
    return rv;
}

static inline bool
getThreadList(SentryCrashMachineContext *context)
{
    const task_t thisTask = mach_task_self();
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Getting thread list");
    kern_return_t kr;
    thread_act_array_t threads;
    mach_msg_type_number_t actualThreadCount;

    if ((kr = task_threads(thisTask, &threads, &actualThreadCount)) != KERN_SUCCESS) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("task_threads: %s", mach_error_string(kr));
        return false;
    }
    SENTRY_ASYNC_SAFE_LOG_TRACE("Got %d threads", context->threadCount);
    int threadCount = (int)actualThreadCount;
    int maxThreadCount = sizeof(context->allThreads) / sizeof(context->allThreads[0]);
    if (threadCount > maxThreadCount) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Thread count %d is higher than maximum of %d", threadCount, maxThreadCount);
        threadCount = maxThreadCount;
    }
    for (int i = 0; i < threadCount; i++) {
        context->allThreads[i] = threads[i];
    }
    context->threadCount = threadCount;

    for (mach_msg_type_number_t i = 0; i < actualThreadCount; i++) {
        mach_port_deallocate(thisTask, context->allThreads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * actualThreadCount);

    return true;
}

int
sentrycrashmc_contextSize(void)
{
    return sizeof(SentryCrashMachineContext);
}

SentryCrashThread
sentrycrashmc_getThreadFromContext(const SentryCrashMachineContext *const context)
{
    return context->thisThread;
}

bool
sentrycrashmc_getContextForThread(
    SentryCrashThread thread, SentryCrashMachineContext *destinationContext, bool isCrashedContext)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Fill thread 0x%x context into %p. is crashed = %d", thread,
        destinationContext, isCrashedContext);
    memset(destinationContext, 0, sizeof(*destinationContext));
    destinationContext->thisThread = (thread_t)thread;
    destinationContext->isCurrentThread = thread == sentrycrashthread_self();
    destinationContext->isCrashedContext = isCrashedContext;
    destinationContext->isSignalContext = false;
    if (sentrycrashmc_canHaveCPUState(destinationContext)) {
        sentrycrashcpu_getState(destinationContext);
    }
    if (sentrycrashmc_isCrashedContext(destinationContext)) {
        destinationContext->isStackOverflow = isStackOverflow(destinationContext);
        getThreadList(destinationContext);
    }
    SENTRY_ASYNC_SAFE_LOG_TRACE("Context retrieved.");
    return true;
}

bool
sentrycrashmc_getContextForSignal(
    void *signalUserContext, SentryCrashMachineContext *destinationContext)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "Get context from signal user context and put into %p.", destinationContext);
    _STRUCT_MCONTEXT *sourceContext = ((SignalUserContext *)signalUserContext)->UC_MCONTEXT;
    memcpy(&destinationContext->machineContext, sourceContext,
        sizeof(destinationContext->machineContext));
    destinationContext->thisThread = (thread_t)sentrycrashthread_self();
    destinationContext->isCrashedContext = true;
    destinationContext->isSignalContext = true;
    destinationContext->isStackOverflow = isStackOverflow(destinationContext);
    getThreadList(destinationContext);
    SENTRY_ASYNC_SAFE_LOG_TRACE("Context retrieved.");
    return true;
}

void
sentrycrashmc_suspendEnvironment(
    thread_act_array_t *suspendedThreads, mach_msg_type_number_t *numSuspendedThreads)
{
    sentrycrashmc_suspendEnvironment_upToMaxSupportedThreads(
        suspendedThreads, numSuspendedThreads, UINT32_MAX);
}

void
sentrycrashmc_suspendEnvironment_upToMaxSupportedThreads(thread_act_array_t *suspendedThreads,
    mach_msg_type_number_t *numSuspendedThreads, mach_msg_type_number_t maxSupportedThreads)
{
#if SENTRY_HAS_THREADS_API
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Suspending environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)sentrycrashthread_self();

    if ((kr = task_threads(thisTask, suspendedThreads, numSuspendedThreads)) != KERN_SUCCESS) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("task_threads: %s", mach_error_string(kr));
        return;
    }

    if (*numSuspendedThreads > maxSupportedThreads) {
        *numSuspendedThreads = 0;
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Too many threads to suspend. Aborting operation.");
        return;
    }

    for (mach_msg_type_number_t i = 0; i < *numSuspendedThreads; i++) {
        thread_t thread = (*suspendedThreads)[i];
        if (thread != thisThread && !sentrycrashcm_isReservedThread(thread)) {
            if ((kr = thread_suspend(thread)) != KERN_SUCCESS) {
                // Record the error and keep going.
                SENTRY_ASYNC_SAFE_LOG_ERROR(
                    "thread_suspend (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Suspend complete.");
#endif
}

void
sentrycrashmc_resumeEnvironment(
    __unused thread_act_array_t threads, __unused mach_msg_type_number_t numThreads)
{
#if SENTRY_HAS_THREADS_API
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Resuming environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)sentrycrashthread_self();

    if (threads == NULL || numThreads == 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("we should call sentrycrashmc_suspendEnvironment() first");
        return;
    }

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        thread_t thread = threads[i];
        if (thread != thisThread && !sentrycrashcm_isReservedThread(thread)) {
            if ((kr = thread_resume(thread)) != KERN_SUCCESS) {
                // Record the error and keep going.
                SENTRY_ASYNC_SAFE_LOG_ERROR(
                    "thread_resume (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Resume complete.");
#endif
}

int
sentrycrashmc_getThreadCount(const SentryCrashMachineContext *const context)
{
    return context->threadCount;
}

SentryCrashThread
sentrycrashmc_getThreadAtIndex(const SentryCrashMachineContext *const context, int index)
{
    return context->allThreads[index];
}

int
sentrycrashmc_indexOfThread(
    const SentryCrashMachineContext *const context, SentryCrashThread thread)
{
    SENTRY_ASYNC_SAFE_LOG_TRACE("check thread vs %d threads", context->threadCount);
    for (int i = 0; i < (int)context->threadCount; i++) {
        SENTRY_ASYNC_SAFE_LOG_TRACE("%d: %x vs %x", i, thread, context->allThreads[i]);
        if (context->allThreads[i] == thread) {
            return i;
        }
    }
    return -1;
}

bool
sentrycrashmc_isCrashedContext(const SentryCrashMachineContext *const context)
{
    return context->isCrashedContext;
}

static inline bool
isContextForCurrentThread(const SentryCrashMachineContext *const context)
{
    return context->isCurrentThread;
}

static inline bool
isSignalContext(const SentryCrashMachineContext *const context)
{
    return context->isSignalContext;
}

bool
sentrycrashmc_canHaveCPUState(const SentryCrashMachineContext *const context)
{
    return !isContextForCurrentThread(context) || isSignalContext(context);
}

bool
sentrycrashmc_hasValidExceptionRegisters(const SentryCrashMachineContext *const context)
{
    return sentrycrashmc_canHaveCPUState(context) && sentrycrashmc_isCrashedContext(context);
}
