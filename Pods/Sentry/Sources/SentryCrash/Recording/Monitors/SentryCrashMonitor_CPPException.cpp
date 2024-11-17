// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor_CPPException.c
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

#include "SentryCrashMonitor_CPPException.h"
#include "SentryCrashID.h"
#include "SentryCrashMachineContext.h"
#include "SentryCrashMonitorContext.h"
#include "SentryCrashStackCursor_SelfThread.h"
#include "SentryCrashThread.h"

#include "SentryAsyncSafeLog.h"

#include <cxxabi.h>
#include <dlfcn.h>
#include <exception>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <typeinfo>

#define STACKTRACE_BUFFER_LENGTH 30
#define DESCRIPTION_BUFFER_LENGTH 1000

// Compiler hints for "if" statements
#define likely_if(x) if (__builtin_expect(x, 1))
#define unlikely_if(x) if (__builtin_expect(x, 0))

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** True if this handler has been installed. */
static volatile bool g_isEnabled = false;

/** True if the handler should capture the next stack trace. */
static bool g_captureNextStackTrace = false;

static std::terminate_handler g_originalTerminateHandler;

static char g_eventID[37];

static SentryCrash_MonitorContext g_monitorContext;

// TODO: Thread local storage is not supported < ios 9.
// Find some other way to do thread local. Maybe storage with lookup by tid?
static SentryCrashStackCursor g_stackCursor;

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

typedef void (*cxa_throw_type)(void *, std::type_info *, void (*)(void *));
typedef void (*cxa_rethrow_type)(void);

extern "C" {
void __cxa_throw(void *thrown_exception, std::type_info *tinfo, void (*dest)(void *))
    __attribute__((weak));

void
__cxa_throw(void *thrown_exception, std::type_info *tinfo, void (*dest)(void *))
{
    if (g_captureNextStackTrace) {
        sentrycrashsc_initSelfThread(&g_stackCursor, 1);
    }

    static cxa_throw_type orig_cxa_throw = NULL;
    unlikely_if(orig_cxa_throw == NULL)
    {
        orig_cxa_throw = (cxa_throw_type)dlsym(RTLD_NEXT, "__cxa_throw");
    }
    orig_cxa_throw(thrown_exception, tinfo, dest);
    __builtin_unreachable();
}

void
__sentry_cxa_throw(void *thrown_exception, std::type_info *tinfo, void (*dest)(void *))
{
    __cxa_throw(thrown_exception, tinfo, dest);
}

void
__sentry_cxa_rethrow()
{
    if (g_captureNextStackTrace) {
        sentrycrashsc_initSelfThread(&g_stackCursor, 1);
    }

    static cxa_rethrow_type orig_cxa_rethrow = NULL;
    unlikely_if(orig_cxa_rethrow == NULL)
    {
        orig_cxa_rethrow = (cxa_rethrow_type)dlsym(RTLD_NEXT, "__cxa_rethrow");
    }
    orig_cxa_rethrow();
    __builtin_unreachable();
}
}

void
sentrycrashcm_cppexception_callOriginalTerminationHandler(void)
{
    // Can be NULL as the return value of set_terminate can be a NULL pointer; see:
    // https://en.cppreference.com/w/cpp/error/set_terminate
    if (g_originalTerminateHandler != NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Calling original terminate handler.");
        g_originalTerminateHandler();
    }
}

static void
CPPExceptionTerminate(void)
{
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t numThreads = 0;
    sentrycrashmc_suspendEnvironment(&threads, &numThreads);
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Trapped c++ exception");
    const char *name = NULL;
    std::type_info *tinfo = __cxxabiv1::__cxa_current_exception_type();
    if (tinfo != NULL) {
        name = tinfo->name();
    }

    if (name == NULL || strcmp(name, "NSException") != 0) {
        sentrycrashcm_notifyFatalExceptionCaptured(false);
        SentryCrash_MonitorContext *crashContext = &g_monitorContext;
        memset(crashContext, 0, sizeof(*crashContext));

        char descriptionBuff[DESCRIPTION_BUFFER_LENGTH];
        const char *description = descriptionBuff;
        descriptionBuff[0] = 0;

        std::exception_ptr currException = std::current_exception();
        if (currException == NULL) {
            SENTRY_ASYNC_SAFE_LOG_DEBUG("Terminate without exception.");
            sentrycrashsc_initSelfThread(&g_stackCursor, 0);
        } else {
            SENTRY_ASYNC_SAFE_LOG_DEBUG("Discovering what kind of exception was thrown.");
            g_captureNextStackTrace = false;
            try {
                throw;
            } catch (std::exception &exc) {
                strncpy(descriptionBuff, exc.what(), sizeof(descriptionBuff));
            }
#define CATCH_VALUE(TYPE, PRINTFTYPE)                                                              \
    catch (TYPE value) {                                                                           \
        snprintf(descriptionBuff, sizeof(descriptionBuff), "%" #PRINTFTYPE, value);                \
    }
            CATCH_VALUE(char, d)
            CATCH_VALUE(short, d)
            CATCH_VALUE(int, d)
            CATCH_VALUE(long, ld)
            CATCH_VALUE(long long, lld)
            CATCH_VALUE(unsigned char, u)
            CATCH_VALUE(unsigned short, u)
            CATCH_VALUE(unsigned int, u)
            CATCH_VALUE(unsigned long, lu)
            CATCH_VALUE(unsigned long long, llu)
            CATCH_VALUE(float, f)
            CATCH_VALUE(double, f)
            CATCH_VALUE(long double, Lf)
            CATCH_VALUE(char *, s)
            catch (...) { description = NULL; }
            g_captureNextStackTrace = g_isEnabled;
        }

        // TODO: Should this be done here? Maybe better in the exception
        // handler?
        SentryCrashMC_NEW_CONTEXT(machineContext);
        sentrycrashmc_getContextForThread(sentrycrashthread_self(), machineContext, true);

        SENTRY_ASYNC_SAFE_LOG_DEBUG("Filling out context.");
        crashContext->crashType = SentryCrashMonitorTypeCPPException;
        crashContext->eventID = g_eventID;
        crashContext->registersAreValid = false;
        crashContext->stackCursor = &g_stackCursor;
        crashContext->CPPException.name = name;
        crashContext->exceptionName = name;
        crashContext->crashReason = description;
        crashContext->offendingMachineContext = machineContext;

        sentrycrashcm_handleException(crashContext);
    } else {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Detected NSException. Letting the current "
                                    "NSException handler deal with it.");
    }
    sentrycrashmc_resumeEnvironment(threads, numThreads);

    sentrycrashcm_cppexception_callOriginalTerminationHandler();
}

// ============================================================================
#pragma mark - Public API -
// ============================================================================

static void
initialize(void)
{
    static bool isInitialized = false;
    if (!isInitialized) {
        isInitialized = true;
        sentrycrashsc_initCursor(&g_stackCursor, NULL, NULL);
    }
}

static void
setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            initialize();

            sentrycrashid_generate(g_eventID);
            g_originalTerminateHandler = std::set_terminate(CPPExceptionTerminate);
        } else {
            std::set_terminate(g_originalTerminateHandler);
            g_originalTerminateHandler = NULL;
        }
        g_captureNextStackTrace = isEnabled;
    }
}

static bool
isEnabled(void)
{
    return g_isEnabled;
}

extern "C" SentryCrashMonitorAPI *
sentrycrashcm_cppexception_getAPI(void)
{
    static SentryCrashMonitorAPI api = { .setEnabled = setEnabled, .isEnabled = isEnabled };
    return &api;
}
