//
//  SentryCrashMach.c
//
// Copyright 2016 Karl Stenerud.
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

#include "SentryCrashMach.h"

#include <mach/mach.h>
#include <stdlib.h>

#define RETURN_NAME_FOR_ENUM(A) case A: return #A

const char* sentrycrashmach_exceptionName(const int64_t exceptionType)
{
    switch (exceptionType)
    {
            RETURN_NAME_FOR_ENUM(EXC_BAD_ACCESS);
            RETURN_NAME_FOR_ENUM(EXC_BAD_INSTRUCTION);
            RETURN_NAME_FOR_ENUM(EXC_ARITHMETIC);
            RETURN_NAME_FOR_ENUM(EXC_EMULATION);
            RETURN_NAME_FOR_ENUM(EXC_SOFTWARE);
            RETURN_NAME_FOR_ENUM(EXC_BREAKPOINT);
            RETURN_NAME_FOR_ENUM(EXC_SYSCALL);
            RETURN_NAME_FOR_ENUM(EXC_MACH_SYSCALL);
            RETURN_NAME_FOR_ENUM(EXC_RPC_ALERT);
            RETURN_NAME_FOR_ENUM(EXC_CRASH);
    }
    return NULL;
}

const char* sentrycrashmach_kernelReturnCodeName(const int64_t returnCode)
{
    switch (returnCode)
    {
            RETURN_NAME_FOR_ENUM(KERN_SUCCESS);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_ADDRESS);
            RETURN_NAME_FOR_ENUM(KERN_PROTECTION_FAILURE);
            RETURN_NAME_FOR_ENUM(KERN_NO_SPACE);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_ARGUMENT);
            RETURN_NAME_FOR_ENUM(KERN_FAILURE);
            RETURN_NAME_FOR_ENUM(KERN_RESOURCE_SHORTAGE);
            RETURN_NAME_FOR_ENUM(KERN_NOT_RECEIVER);
            RETURN_NAME_FOR_ENUM(KERN_NO_ACCESS);
            RETURN_NAME_FOR_ENUM(KERN_MEMORY_FAILURE);
            RETURN_NAME_FOR_ENUM(KERN_MEMORY_ERROR);
            RETURN_NAME_FOR_ENUM(KERN_ALREADY_IN_SET);
            RETURN_NAME_FOR_ENUM(KERN_NOT_IN_SET);
            RETURN_NAME_FOR_ENUM(KERN_NAME_EXISTS);
            RETURN_NAME_FOR_ENUM(KERN_ABORTED);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_NAME);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_TASK);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_RIGHT);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_VALUE);
            RETURN_NAME_FOR_ENUM(KERN_UREFS_OVERFLOW);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_CAPABILITY);
            RETURN_NAME_FOR_ENUM(KERN_RIGHT_EXISTS);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_HOST);
            RETURN_NAME_FOR_ENUM(KERN_MEMORY_PRESENT);
            RETURN_NAME_FOR_ENUM(KERN_MEMORY_DATA_MOVED);
            RETURN_NAME_FOR_ENUM(KERN_MEMORY_RESTART_COPY);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_PROCESSOR_SET);
            RETURN_NAME_FOR_ENUM(KERN_POLICY_LIMIT);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_POLICY);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_OBJECT);
            RETURN_NAME_FOR_ENUM(KERN_ALREADY_WAITING);
            RETURN_NAME_FOR_ENUM(KERN_DEFAULT_SET);
            RETURN_NAME_FOR_ENUM(KERN_EXCEPTION_PROTECTED);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_LEDGER);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_MEMORY_CONTROL);
            RETURN_NAME_FOR_ENUM(KERN_INVALID_SECURITY);
            RETURN_NAME_FOR_ENUM(KERN_NOT_DEPRESSED);
            RETURN_NAME_FOR_ENUM(KERN_TERMINATED);
            RETURN_NAME_FOR_ENUM(KERN_LOCK_SET_DESTROYED);
            RETURN_NAME_FOR_ENUM(KERN_LOCK_UNSTABLE);
            RETURN_NAME_FOR_ENUM(KERN_LOCK_OWNED);
            RETURN_NAME_FOR_ENUM(KERN_LOCK_OWNED_SELF);
            RETURN_NAME_FOR_ENUM(KERN_SEMAPHORE_DESTROYED);
            RETURN_NAME_FOR_ENUM(KERN_RPC_SERVER_TERMINATED);
            RETURN_NAME_FOR_ENUM(KERN_RPC_TERMINATE_ORPHAN);
            RETURN_NAME_FOR_ENUM(KERN_RPC_CONTINUE_ORPHAN);
            RETURN_NAME_FOR_ENUM(KERN_NOT_SUPPORTED);
            RETURN_NAME_FOR_ENUM(KERN_NODE_DOWN);
            RETURN_NAME_FOR_ENUM(KERN_NOT_WAITING);
            RETURN_NAME_FOR_ENUM(KERN_OPERATION_TIMED_OUT);
            RETURN_NAME_FOR_ENUM(KERN_CODESIGN_ERROR);
    }
    return NULL;
}

#define EXC_UNIX_BAD_SYSCALL 0x10000 /* SIGSYS */
#define EXC_UNIX_BAD_PIPE    0x10001 /* SIGPIPE */
#define EXC_UNIX_ABORT       0x10002 /* SIGABRT */

int sentrycrashmach_machExceptionForSignal(const int sigNum)
{
    switch(sigNum)
    {
        case SIGFPE:
            return EXC_ARITHMETIC;
        case SIGSEGV:
            return EXC_BAD_ACCESS;
        case SIGBUS:
            return EXC_BAD_ACCESS;
        case SIGILL:
            return EXC_BAD_INSTRUCTION;
        case SIGTRAP:
            return EXC_BREAKPOINT;
        case SIGEMT:
            return EXC_EMULATION;
        case SIGSYS:
            return EXC_UNIX_BAD_SYSCALL;
        case SIGPIPE:
            return EXC_UNIX_BAD_PIPE;
        case SIGABRT:
            // The Apple reporter uses EXC_CRASH instead of EXC_UNIX_ABORT
            return EXC_CRASH;
        case SIGKILL:
            return EXC_SOFT_SIGNAL;
    }
    return 0;
}

int sentrycrashmach_signalForMachException(const int exception,
                                  const mach_exception_code_t code)
{
    switch(exception)
    {
        case EXC_ARITHMETIC:
            return SIGFPE;
        case EXC_BAD_ACCESS:
            return code == KERN_INVALID_ADDRESS ? SIGSEGV : SIGBUS;
        case EXC_BAD_INSTRUCTION:
            return SIGILL;
        case EXC_BREAKPOINT:
            return SIGTRAP;
        case EXC_EMULATION:
            return SIGEMT;
        case EXC_SOFTWARE:
        {
            switch (code)
            {
                case EXC_UNIX_BAD_SYSCALL:
                    return SIGSYS;
                case EXC_UNIX_BAD_PIPE:
                    return SIGPIPE;
                case EXC_UNIX_ABORT:
                    return SIGABRT;
                case EXC_SOFT_SIGNAL:
                    return SIGKILL;
            }
            break;
        }
    }
    return 0;
}
