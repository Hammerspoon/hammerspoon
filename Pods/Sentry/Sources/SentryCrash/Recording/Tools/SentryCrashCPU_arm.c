// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashCPU_arm.c
//
//  Created by Karl Stenerud on 2012-01-29.
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

#if defined(__arm__)

#    include "SentryCrashCPU.h"
#    include "SentryCrashCPU_Apple.h"
#    include "SentryCrashMachineContext.h"
#    include "SentryCrashMachineContext_Apple.h"
#    include <stdlib.h>

// #define SentryCrashLogger_LocalLevel TRACE
#    include "SentryCrashLogger.h"

static const char *g_registerNames[] = { "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9",
    "r10", "r11", "ip", "sp", "lr", "pc", "cpsr" };
static const int g_registerNamesCount = sizeof(g_registerNames) / sizeof(*g_registerNames);

static const char *g_exceptionRegisterNames[] = { "exception", "fsr", "far" };
static const int g_exceptionRegisterNamesCount
    = sizeof(g_exceptionRegisterNames) / sizeof(*g_exceptionRegisterNames);

uintptr_t
sentrycrashcpu_framePointer(const SentryCrashMachineContext *const context)
{
    return context->machineContext.__ss.__r[7];
}

uintptr_t
sentrycrashcpu_stackPointer(const SentryCrashMachineContext *const context)
{
    return context->machineContext.__ss.__sp;
}

uintptr_t
sentrycrashcpu_instructionAddress(const SentryCrashMachineContext *const context)
{
    return context->machineContext.__ss.__pc;
}

uintptr_t
sentrycrashcpu_linkRegister(const SentryCrashMachineContext *const context)
{
    return context->machineContext.__ss.__lr;
}

void
sentrycrashcpu_getState(SentryCrashMachineContext *context)
{
    thread_t thread = context->thisThread;
    STRUCT_MCONTEXT_L *const machineContext = &context->machineContext;

    sentrycrashcpu_i_fillState(
        thread, (thread_state_t)&machineContext->__ss, ARM_THREAD_STATE, ARM_THREAD_STATE_COUNT);
    sentrycrashcpu_i_fillState(thread, (thread_state_t)&machineContext->__es, ARM_EXCEPTION_STATE,
        ARM_EXCEPTION_STATE_COUNT);
}

int
sentrycrashcpu_numRegisters(void)
{
    return g_registerNamesCount;
}

const char *
sentrycrashcpu_registerName(const int regNumber)
{
    if (regNumber < sentrycrashcpu_numRegisters()) {
        return g_registerNames[regNumber];
    }
    return NULL;
}

uint64_t
sentrycrashcpu_registerValue(const SentryCrashMachineContext *const context, const int regNumber)
{
    if (regNumber <= 12) {
        return context->machineContext.__ss.__r[regNumber];
    }

    switch (regNumber) {
    case 13:
        return context->machineContext.__ss.__sp;
    case 14:
        return context->machineContext.__ss.__lr;
    case 15:
        return context->machineContext.__ss.__pc;
    case 16:
        return context->machineContext.__ss.__cpsr;
    }

    SentryCrashLOG_ERROR("Invalid register number: %d", regNumber);
    return 0;
}

int
sentrycrashcpu_numExceptionRegisters(void)
{
    return g_exceptionRegisterNamesCount;
}

const char *
sentrycrashcpu_exceptionRegisterName(const int regNumber)
{
    if (regNumber < sentrycrashcpu_numExceptionRegisters()) {
        return g_exceptionRegisterNames[regNumber];
    }
    SentryCrashLOG_ERROR("Invalid register number: %d", regNumber);
    return NULL;
}

uint64_t
sentrycrashcpu_exceptionRegisterValue(
    const SentryCrashMachineContext *const context, const int regNumber)
{
    switch (regNumber) {
    case 0:
        return context->machineContext.__es.__exception;
    case 1:
        return context->machineContext.__es.__fsr;
    case 2:
        return context->machineContext.__es.__far;
    }

    SentryCrashLOG_ERROR("Invalid register number: %d", regNumber);
    return 0;
}

uintptr_t
sentrycrashcpu_faultAddress(const SentryCrashMachineContext *const context)
{
    return context->machineContext.__es.__far;
}

int
sentrycrashcpu_stackGrowDirection(void)
{
    return -1;
}

uintptr_t
sentrycrashcpu_normaliseInstructionPointer(uintptr_t ip)
{
    return ip;
}

#endif
