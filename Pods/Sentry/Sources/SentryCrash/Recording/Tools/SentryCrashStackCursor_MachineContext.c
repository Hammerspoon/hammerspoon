// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashStackCursor_MachineContext.c
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
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

#include "SentryCrashStackCursor_MachineContext.h"

#include "SentryCrashCPU.h"
#include "SentryCrashMemory.h"

#include <stdlib.h>

#include "SentryAsyncSafeLog.h"

/** Represents an entry in a frame list.
 * This is modeled after the various i386/x64 frame walkers in the xnu source,
 * and seems to work fine in ARM as well. I haven't included the args pointer
 * since it's not needed in this context.
 */
typedef struct FrameEntry {
    /** The previous frame in the list. */
    struct FrameEntry *previous;

    /** The instruction address. */
    uintptr_t return_address;
} FrameEntry;

typedef struct {
    const struct SentryCrashMachineContext *machineContext;
    int maxStackDepth;
    FrameEntry currentFrame;
    uintptr_t instructionAddress;
    uintptr_t linkRegister;
    bool isPastFramePointer;
} MachineContextCursor;

static bool
advanceCursor(SentryCrashStackCursor *cursor)
{
    MachineContextCursor *context = (MachineContextCursor *)cursor->context;
    uintptr_t nextAddress = 0;

    if (cursor->state.currentDepth >= context->maxStackDepth) {
        cursor->state.hasGivenUp = true;
        return false;
    }

    if (context->instructionAddress == 0) {
        context->instructionAddress = sentrycrashcpu_instructionAddress(context->machineContext);
        if (context->instructionAddress == 0) {
            goto tryAsyncChain;
        }
        nextAddress = context->instructionAddress;
        goto successfulExit;
    }

    if (context->linkRegister == 0 && !context->isPastFramePointer) {
        // Link register, if available, is the second address in the trace.
        context->linkRegister = sentrycrashcpu_linkRegister(context->machineContext);
        if (context->linkRegister != 0) {
            nextAddress = context->linkRegister;
            goto successfulExit;
        }
    }

    if (context->currentFrame.previous == NULL) {
        if (context->isPastFramePointer) {
            goto tryAsyncChain;
        }
        context->currentFrame.previous
            = (struct FrameEntry *)sentrycrashcpu_framePointer(context->machineContext);
        context->isPastFramePointer = true;
    }

    if (!sentrycrashmem_copySafely(context->currentFrame.previous, &context->currentFrame,
            sizeof(context->currentFrame))) {
        return false;
    }
    if (context->currentFrame.previous == 0 || context->currentFrame.return_address == 0) {
        goto tryAsyncChain;
    }

    nextAddress = context->currentFrame.return_address;

successfulExit:
    cursor->stackEntry.address = sentrycrashcpu_normaliseInstructionPointer(nextAddress);
    cursor->state.currentDepth++;
    return true;

tryAsyncChain:
    return false;
}

static void
resetCursor(SentryCrashStackCursor *cursor)
{
    sentrycrashsc_resetCursor(cursor);
    MachineContextCursor *context = (MachineContextCursor *)cursor->context;
    context->currentFrame.previous = 0;
    context->currentFrame.return_address = 0;
    context->instructionAddress = 0;
    context->linkRegister = 0;
    context->isPastFramePointer = 0;
}

void
sentrycrashsc_initWithMachineContext(SentryCrashStackCursor *cursor, int maxStackDepth,
    const struct SentryCrashMachineContext *machineContext)
{
    sentrycrashsc_initCursor(cursor, resetCursor, advanceCursor);
    MachineContextCursor *context = (MachineContextCursor *)cursor->context;
    context->machineContext = machineContext;
    context->maxStackDepth = maxStackDepth;
    context->instructionAddress = cursor->stackEntry.address;
}
