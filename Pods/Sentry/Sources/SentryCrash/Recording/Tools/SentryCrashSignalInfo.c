// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashSignalInfo.c
//
//  Created by Karl Stenerud on 2012-02-03.
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

#include "SentryCrashSignalInfo.h"

#include <signal.h>
#include <stdlib.h>

typedef struct {
    const int code;
    const char *const name;
} SentryCrashSignalCodeInfo;

typedef struct {
    const int sigNum;
    const char *const name;
    const SentryCrashSignalCodeInfo *const codes;
    const int numCodes;
} SentryCrashSignalInfo;

#define ENUM_NAME_MAPPING(A) { A, #A }

static const SentryCrashSignalCodeInfo g_sigIllCodes[] = {
#ifdef ILL_NOOP
    ENUM_NAME_MAPPING(ILL_NOOP),
#endif
    ENUM_NAME_MAPPING(ILL_ILLOPC),
    ENUM_NAME_MAPPING(ILL_ILLTRP),
    ENUM_NAME_MAPPING(ILL_PRVOPC),
    ENUM_NAME_MAPPING(ILL_ILLOPN),
    ENUM_NAME_MAPPING(ILL_ILLADR),
    ENUM_NAME_MAPPING(ILL_PRVREG),
    ENUM_NAME_MAPPING(ILL_COPROC),
    ENUM_NAME_MAPPING(ILL_BADSTK),
};

static const SentryCrashSignalCodeInfo g_sigTrapCodes[] = {
    ENUM_NAME_MAPPING(0),
    ENUM_NAME_MAPPING(TRAP_BRKPT),
    ENUM_NAME_MAPPING(TRAP_TRACE),
};

static const SentryCrashSignalCodeInfo g_sigFPECodes[] = {
#ifdef FPE_NOOP
    ENUM_NAME_MAPPING(FPE_NOOP),
#endif
    ENUM_NAME_MAPPING(FPE_FLTDIV),
    ENUM_NAME_MAPPING(FPE_FLTOVF),
    ENUM_NAME_MAPPING(FPE_FLTUND),
    ENUM_NAME_MAPPING(FPE_FLTRES),
    ENUM_NAME_MAPPING(FPE_FLTINV),
    ENUM_NAME_MAPPING(FPE_FLTSUB),
    ENUM_NAME_MAPPING(FPE_INTDIV),
    ENUM_NAME_MAPPING(FPE_INTOVF),
};

static const SentryCrashSignalCodeInfo g_sigBusCodes[] = {
#ifdef BUS_NOOP
    ENUM_NAME_MAPPING(BUS_NOOP),
#endif
    ENUM_NAME_MAPPING(BUS_ADRALN),
    ENUM_NAME_MAPPING(BUS_ADRERR),
    ENUM_NAME_MAPPING(BUS_OBJERR),
};

static const SentryCrashSignalCodeInfo g_sigSegVCodes[] = {
#ifdef SEGV_NOOP
    ENUM_NAME_MAPPING(SEGV_NOOP),
#endif
    ENUM_NAME_MAPPING(SEGV_MAPERR),
    ENUM_NAME_MAPPING(SEGV_ACCERR),
};

#define SIGNAL_INFO(SIGNAL, CODES) { SIGNAL, #SIGNAL, CODES, sizeof(CODES) / sizeof(*CODES) }
#define SIGNAL_INFO_NOCODES(SIGNAL) { SIGNAL, #SIGNAL, 0, 0 }

static const SentryCrashSignalInfo g_fatalSignalData[] = {
    SIGNAL_INFO_NOCODES(SIGABRT),
    SIGNAL_INFO(SIGBUS, g_sigBusCodes),
    SIGNAL_INFO(SIGFPE, g_sigFPECodes),
    SIGNAL_INFO(SIGILL, g_sigIllCodes),
    SIGNAL_INFO_NOCODES(SIGPIPE),
    SIGNAL_INFO(SIGSEGV, g_sigSegVCodes),
    SIGNAL_INFO_NOCODES(SIGSYS),
    SIGNAL_INFO(SIGTRAP, g_sigTrapCodes),
    SIGNAL_INFO_NOCODES(SIGTERM),
};
static const int g_fatalSignalsCount = sizeof(g_fatalSignalData) / sizeof(*g_fatalSignalData);

// Note: Dereferencing a NULL pointer causes SIGILL, ILL_ILLOPC on i386
//       but causes SIGTRAP, 0 on arm.
static const int g_fatalSignals[] = {
    SIGABRT,
    SIGBUS,
    SIGFPE,
    SIGILL,
    SIGPIPE,
    SIGSEGV,
    SIGSYS,
    SIGTRAP,

    // SIGTERM can be caught and is usually sent by iOS and variants
    // when Apple wants to try and gracefully shutdown the app
    // before sending a SIGKILL (which can't be caught).
    // Some areas this might happen are:
    // - When the OS updates an app.
    // - In some circumstances for Watchdog Events.
    // - Resource overuse (CPU, Disk, ...).
    SIGTERM,
};

const char *
sentrycrashsignal_signalName(const int sigNum)
{
    for (int i = 0; i < g_fatalSignalsCount; i++) {
        if (g_fatalSignalData[i].sigNum == sigNum) {
            return g_fatalSignalData[i].name;
        }
    }
    return NULL;
}

const char *
sentrycrashsignal_signalCodeName(const int sigNum, const int code)
{
    for (int si = 0; si < g_fatalSignalsCount; si++) {
        if (g_fatalSignalData[si].sigNum == sigNum) {
            for (int ci = 0; ci < g_fatalSignalData[si].numCodes; ci++) {
                if (g_fatalSignalData[si].codes[ci].code == code) {
                    return g_fatalSignalData[si].codes[ci].name;
                }
            }
        }
    }
    return NULL;
}

const int *
sentrycrashsignal_fatalSignals(void)
{
    return g_fatalSignals;
}

int
sentrycrashsignal_numFatalSignals(void)
{
    return g_fatalSignalsCount;
}
