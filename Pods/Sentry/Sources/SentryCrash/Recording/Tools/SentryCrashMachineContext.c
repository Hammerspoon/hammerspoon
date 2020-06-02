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

#include "SentryCrashMachineContext_Apple.h"
#include "SentryCrashMachineContext.h"
#include "SentryCrashSystemCapabilities.h"
#include "SentryCrashCPU.h"
#include "SentryCrashCPU_Apple.h"
#include "SentryCrashStackCursor_MachineContext.h"

#include <mach/mach.h>

//#define SentryCrashLogger_LocalLevel TRACE
#include "SentryCrashLogger.h"

#ifdef __arm64__
    #define UC_MCONTEXT uc_mcontext64
    typedef ucontext64_t SignalUserContext;
#else
    #define UC_MCONTEXT uc_mcontext
    typedef ucontext_t SignalUserContext;
#endif

static SentryCrashThread g_reservedThreads[10];
static int g_reservedThreadsMaxIndex = sizeof(g_reservedThreads) / sizeof(g_reservedThreads[0]) - 1;
static int g_reservedThreadsCount = 0;



static inline bool isStackOverflow(const SentryCrashMachineContext* const context)
{
    SentryCrashStackCursor stackCursor;
    sentrycrashsc_initWithMachineContext(&stackCursor, SentryCrashSC_STACK_OVERFLOW_THRESHOLD, context);
    while(stackCursor.advanceCursor(&stackCursor))
    {
    }
    return stackCursor.state.hasGivenUp;
}

static inline bool getThreadList(SentryCrashMachineContext* context)
{
    const task_t thisTask = mach_task_self();
    SentryCrashLOG_DEBUG("Getting thread list");
    kern_return_t kr;
    thread_act_array_t threads;
    mach_msg_type_number_t actualThreadCount;

    if((kr = task_threads(thisTask, &threads, &actualThreadCount)) != KERN_SUCCESS)
    {
        SentryCrashLOG_ERROR("task_threads: %s", mach_error_string(kr));
        return false;
    }
    SentryCrashLOG_TRACE("Got %d threads", context->threadCount);
    int threadCount = (int)actualThreadCount;
    int maxThreadCount = sizeof(context->allThreads) / sizeof(context->allThreads[0]);
    if(threadCount > maxThreadCount)
    {
        SentryCrashLOG_ERROR("Thread count %d is higher than maximum of %d", threadCount, maxThreadCount);
        threadCount = maxThreadCount;
    }
    for(int i = 0; i < threadCount; i++)
    {
        context->allThreads[i] = threads[i];
    }
    context->threadCount = threadCount;

    for(mach_msg_type_number_t i = 0; i < actualThreadCount; i++)
    {
        mach_port_deallocate(thisTask, context->allThreads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * actualThreadCount);

    return true;
}

int sentrycrashmc_contextSize()
{
    return sizeof(SentryCrashMachineContext);
}

SentryCrashThread sentrycrashmc_getThreadFromContext(const SentryCrashMachineContext* const context)
{
    return context->thisThread;
}

bool sentrycrashmc_getContextForThread(SentryCrashThread thread, SentryCrashMachineContext* destinationContext, bool isCrashedContext)
{
    SentryCrashLOG_DEBUG("Fill thread 0x%x context into %p. is crashed = %d", thread, destinationContext, isCrashedContext);
    memset(destinationContext, 0, sizeof(*destinationContext));
    destinationContext->thisThread = (thread_t)thread;
    destinationContext->isCurrentThread = thread == sentrycrashthread_self();
    destinationContext->isCrashedContext = isCrashedContext;
    destinationContext->isSignalContext = false;
    if(sentrycrashmc_canHaveCPUState(destinationContext))
    {
        sentrycrashcpu_getState(destinationContext);
    }
    if(sentrycrashmc_isCrashedContext(destinationContext))
    {
        destinationContext->isStackOverflow = isStackOverflow(destinationContext);
        getThreadList(destinationContext);
    }
    SentryCrashLOG_TRACE("Context retrieved.");
    return true;
}

bool sentrycrashmc_getContextForSignal(void* signalUserContext, SentryCrashMachineContext* destinationContext)
{
    SentryCrashLOG_DEBUG("Get context from signal user context and put into %p.", destinationContext);
    _STRUCT_MCONTEXT* sourceContext = ((SignalUserContext*)signalUserContext)->UC_MCONTEXT;
    memcpy(&destinationContext->machineContext, sourceContext, sizeof(destinationContext->machineContext));
    destinationContext->thisThread = (thread_t)sentrycrashthread_self();
    destinationContext->isCrashedContext = true;
    destinationContext->isSignalContext = true;
    destinationContext->isStackOverflow = isStackOverflow(destinationContext);
    getThreadList(destinationContext);
    SentryCrashLOG_TRACE("Context retrieved.");
    return true;
}

void sentrycrashmc_addReservedThread(SentryCrashThread thread)
{
    int nextIndex = g_reservedThreadsCount;
    if(nextIndex > g_reservedThreadsMaxIndex)
    {
        SentryCrashLOG_ERROR("Too many reserved threads (%d). Max is %d", nextIndex, g_reservedThreadsMaxIndex);
        return;
    }
    g_reservedThreads[g_reservedThreadsCount++] = thread;
}

#if SentryCrashCRASH_HAS_THREADS_API
static inline bool isThreadInList(thread_t thread, SentryCrashThread* list, int listCount)
{
    for(int i = 0; i < listCount; i++)
    {
        if(list[i] == (SentryCrashThread)thread)
        {
            return true;
        }
    }
    return false;
}
#endif

void sentrycrashmc_suspendEnvironment()
{
#if SentryCrashCRASH_HAS_THREADS_API
    SentryCrashLOG_DEBUG("Suspending environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)sentrycrashthread_self();
    thread_act_array_t threads;
    mach_msg_type_number_t numThreads;

    if((kr = task_threads(thisTask, &threads, &numThreads)) != KERN_SUCCESS)
    {
        SentryCrashLOG_ERROR("task_threads: %s", mach_error_string(kr));
        return;
    }

    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        thread_t thread = threads[i];
        if(thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount))
        {
            if((kr = thread_suspend(thread)) != KERN_SUCCESS)
            {
                // Record the error and keep going.
                SentryCrashLOG_ERROR("thread_suspend (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);

    SentryCrashLOG_DEBUG("Suspend complete.");
#endif
}

void sentrycrashmc_resumeEnvironment()
{
#if SentryCrashCRASH_HAS_THREADS_API
    SentryCrashLOG_DEBUG("Resuming environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)sentrycrashthread_self();
    thread_act_array_t threads;
    mach_msg_type_number_t numThreads;

    if((kr = task_threads(thisTask, &threads, &numThreads)) != KERN_SUCCESS)
    {
        SentryCrashLOG_ERROR("task_threads: %s", mach_error_string(kr));
        return;
    }

    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        thread_t thread = threads[i];
        if(thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount))
        {
            if((kr = thread_resume(thread)) != KERN_SUCCESS)
            {
                // Record the error and keep going.
                SentryCrashLOG_ERROR("thread_resume (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);

    SentryCrashLOG_DEBUG("Resume complete.");
#endif
}

int sentrycrashmc_getThreadCount(const SentryCrashMachineContext* const context)
{
    return context->threadCount;
}

SentryCrashThread sentrycrashmc_getThreadAtIndex(const SentryCrashMachineContext* const context, int index)
{
    return context->allThreads[index];

}

int sentrycrashmc_indexOfThread(const SentryCrashMachineContext* const context, SentryCrashThread thread)
{
    SentryCrashLOG_TRACE("check thread vs %d threads", context->threadCount);
    for(int i = 0; i < (int)context->threadCount; i++)
    {
        SentryCrashLOG_TRACE("%d: %x vs %x", i, thread, context->allThreads[i]);
        if(context->allThreads[i] == thread)
        {
            return i;
        }
    }
    return -1;
}

bool sentrycrashmc_isCrashedContext(const SentryCrashMachineContext* const context)
{
    return context->isCrashedContext;
}

static inline bool isContextForCurrentThread(const SentryCrashMachineContext* const context)
{
    return context->isCurrentThread;
}

static inline bool isSignalContext(const SentryCrashMachineContext* const context)
{
    return context->isSignalContext;
}

bool sentrycrashmc_canHaveCPUState(const SentryCrashMachineContext* const context)
{
    return !isContextForCurrentThread(context) || isSignalContext(context);
}

bool sentrycrashmc_hasValidExceptionRegisters(const SentryCrashMachineContext* const context)
{
    return sentrycrashmc_canHaveCPUState(context) && sentrycrashmc_isCrashedContext(context);
}
