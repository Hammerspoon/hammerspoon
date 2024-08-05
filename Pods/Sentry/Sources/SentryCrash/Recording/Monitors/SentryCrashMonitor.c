// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor.c
//
//  Created by Karl Stenerud on 2012-02-12.
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

#include "SentryCrashMonitor.h"
#include "SentryCrashMonitorContext.h"
#include "SentryCrashMonitorType.h"

#include "SentryCrashDebug.h"
#include "SentryCrashMonitor_AppState.h"
#include "SentryCrashMonitor_CPPException.h"
#include "SentryCrashMonitor_MachException.h"
#include "SentryCrashMonitor_NSException.h"
#include "SentryCrashMonitor_Signal.h"
#include "SentryCrashMonitor_System.h"
#include "SentryCrashThread.h"
#include "SentryInternalCDefines.h"

#include <memory.h>

#include "SentryAsyncSafeLog.h"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

typedef struct {
    SentryCrashMonitorType monitorType;
    SentryCrashMonitorAPI *(*getAPI)(void);
} Monitor;

static Monitor g_monitors[] = {
#if SENTRY_HAS_MACH
    {
        .monitorType = SentryCrashMonitorTypeMachException,
        .getAPI = sentrycrashcm_machexception_getAPI,
    },
#endif
#if SENTRY_HAS_SIGNAL
    {
        .monitorType = SentryCrashMonitorTypeSignal,
        .getAPI = sentrycrashcm_signal_getAPI,
    },
#endif
    {
        .monitorType = SentryCrashMonitorTypeNSException,
        .getAPI = sentrycrashcm_nsexception_getAPI,
    },
    {
        .monitorType = SentryCrashMonitorTypeCPPException,
        .getAPI = sentrycrashcm_cppexception_getAPI,
    },
    {
        .monitorType = SentryCrashMonitorTypeApplicationState,
        .getAPI = sentrycrashcm_appstate_getAPI,
    },
};
static int g_monitorsCount = sizeof(g_monitors) / sizeof(*g_monitors);

static SentryCrashMonitorType g_activeMonitors = SentryCrashMonitorTypeNone;

static bool g_handlingFatalException = false;
static bool g_crashedDuringExceptionHandling = false;
static bool g_requiresAsyncSafety = false;

static void (*g_onExceptionEvent)(struct SentryCrash_MonitorContext *monitorContext);

// ============================================================================
#pragma mark - API -
// ============================================================================

static inline SentryCrashMonitorAPI *
getAPI(Monitor *monitor)
{
    if (monitor != NULL && monitor->getAPI != NULL) {
        return monitor->getAPI();
    }
    return NULL;
}

static inline void
setMonitorEnabled(Monitor *monitor, bool isEnabled)
{
    SentryCrashMonitorAPI *api = getAPI(monitor);
    if (api != NULL && api->setEnabled != NULL) {
        api->setEnabled(isEnabled);
    }
}

static inline bool
isMonitorEnabled(Monitor *monitor)
{
    SentryCrashMonitorAPI *api = getAPI(monitor);
    if (api != NULL && api->isEnabled != NULL) {
        return api->isEnabled();
    }
    return false;
}

static inline void
addContextualInfoToEvent(Monitor *monitor, struct SentryCrash_MonitorContext *eventContext)
{
    SentryCrashMonitorAPI *api = getAPI(monitor);
    if (api != NULL && api->addContextualInfoToEvent != NULL) {
        api->addContextualInfoToEvent(eventContext);
    }
}

void
sentrycrashcm_setEventCallback(SentryCrashMonitorEventCallback onEvent)
{
    g_onExceptionEvent = onEvent;
}

SentryCrashMonitorEventCallback
sentrycrashcm_getEventCallback(void)
{
    return g_onExceptionEvent;
}

void
sentrycrashcm_setActiveMonitors(SentryCrashMonitorType monitorTypes)
{
    if (sentrycrashdebug_isBeingTraced() && (monitorTypes & SentryCrashMonitorTypeDebuggerUnsafe)) {
        static bool hasWarned = false;
        if (!hasWarned) {
            hasWarned = true;
            SENTRY_ASYNC_SAFE_LOG_WARN("App is running in a debugger. Masking out unsafe monitors. "
                                       "This means that most crashes WILL "
                                       "NOT BE RECORDED while debugging!");
        }
        monitorTypes &= SentryCrashMonitorTypeDebuggerSafe;
    }
    if (g_requiresAsyncSafety && (monitorTypes & SentryCrashMonitorTypeAsyncUnsafe)) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Async-safe environment detected. Masking out unsafe monitors.");
        monitorTypes &= SentryCrashMonitorTypeAsyncSafe;
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "Changing active monitors from 0x%x tp 0x%x.", g_activeMonitors, monitorTypes);

    SentryCrashMonitorType activeMonitors = SentryCrashMonitorTypeNone;
    for (int i = 0; i < g_monitorsCount; i++) {
        Monitor *monitor = &g_monitors[i];
        bool isEnabled = monitor->monitorType & monitorTypes;
        setMonitorEnabled(monitor, isEnabled);
        if (isMonitorEnabled(monitor)) {
            activeMonitors |= monitor->monitorType;
        } else {
            activeMonitors &= ~monitor->monitorType;
        }
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Active monitors are now 0x%x.", activeMonitors);
    g_activeMonitors = activeMonitors;
}

SentryCrashMonitorType
sentrycrashcm_getActiveMonitors(void)
{
    return g_activeMonitors;
}

// ============================================================================
#pragma mark - Private API -
// ============================================================================

bool
sentrycrashcm_notifyFatalExceptionCaptured(bool isAsyncSafeEnvironment)
{
    g_requiresAsyncSafety |= isAsyncSafeEnvironment; // Don't let it be unset.
    if (g_handlingFatalException) {
        g_crashedDuringExceptionHandling = true;
    }
    g_handlingFatalException = true;
    if (g_crashedDuringExceptionHandling) {
        SENTRY_ASYNC_SAFE_LOG_INFO(
            "Detected crash in the crash reporter. Uninstalling SentryCrash.");
        sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNone);
    }
    return g_crashedDuringExceptionHandling;
}

void
sentrycrashcm_handleException(struct SentryCrash_MonitorContext *context)
{
    context->requiresAsyncSafety = g_requiresAsyncSafety;
    if (g_crashedDuringExceptionHandling) {
        context->crashedDuringCrashHandling = true;
    }
    for (int i = 0; i < g_monitorsCount; i++) {
        Monitor *monitor = &g_monitors[i];
        if (isMonitorEnabled(monitor)) {
            addContextualInfoToEvent(monitor, context);
        }
    }

    g_onExceptionEvent(context);

    if (g_handlingFatalException && !g_crashedDuringExceptionHandling) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Exception is fatal. Restoring original handlers.");
        sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNone);
    }
}
