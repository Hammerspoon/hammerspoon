#pragma once

#include "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryCPU.h"
#    include "SentryCompiler.h"
#    include "SentryStackFrame.hpp"
#    include "SentryThreadHandle.hpp"

#    include <cstdint>
#    include <mach/mach.h>
#    include <sys/types.h>

namespace sentry {
namespace profiling {
    namespace thread {

        using MachineContext = _STRUCT_MCONTEXT;

        /**
         * Fills in thread state information in the specified machine context structure.
         *
         * @param thread The thread to get state information from.
         * @param context The machine context structure to fill state information into.
         * @return Kernel return code indicating success or failure.
         */
        ALWAYS_INLINE kern_return_t
        fillThreadState(ThreadHandle::NativeHandle thread, MachineContext *context) noexcept
        {
#    if CPU(X86_64)
#        define SENTRY_THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#        define SENTRY_THREAD_STATE_FLAVOR x86_THREAD_STATE64
#    elif CPU(X86)
#        define SENTRY_THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#        define SENTRY_THREAD_STATE_FLAVOR x86_THREAD_STATE32
#    elif CPU(ARM64)
#        define SENTRY_THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#        define SENTRY_THREAD_STATE_FLAVOR ARM_THREAD_STATE64
#    elif CPU(ARM)
#        define SENTRY_THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#        define SENTRY_THREAD_STATE_FLAVOR ARM_THREAD_STATE
#    else
#        error Unsupported architecture!
#    endif
            mach_msg_type_number_t count = SENTRY_THREAD_STATE_COUNT;
            return thread_get_state(
                thread, SENTRY_THREAD_STATE_FLAVOR, (thread_state_t)&context->__ss, &count);
        }

        /**
         * Returns the frame address value from the specified machine context.
         *
         * @param context Machine context to get frame address from.
         * @return The frame address value.
         */
        ALWAYS_INLINE std::uintptr_t
        getFrameAddress(const MachineContext *context) noexcept
        {
            // Program must be compiled with `-fno-omit-frame-pointer` to avoid
            // frame pointer optimization.
            // https://gcc.gnu.org/onlinedocs/gcc-4.9.2/gcc/Optimize-Options.html
            // http://www.keil.com/support/man/docs/armclang_ref/armclang_ref_vvi1466179578564.htm
#    if CPU(X86_64)
            return context->__ss.__rbp;
#    elif CPU(X86)
            return context->__ss.__ebp;
#    elif CPU(ARM64)
            // fp is an alias for frame pointer register x29:
            // https://developer.apple.com/library/archive/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARM64FunctionCallingConventions.html
            return context->__ss.__fp;
#    elif CPU(ARM)
            // https://developer.apple.com/library/archive/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARMv6FunctionCallingConventions.html#//apple_ref/doc/uid/TP40009021-SW1
            return context->__ss.__r[7];
#    else
#        error Unsupported architecture!
#    endif
        }

        /**
         * Returns the return address of the current function.
         *
         * @param context Machine context to get the program counter value from.
         * @return The return address of the current function, i.e. the address of the
         * calling function.
         */
        ALWAYS_INLINE std::uintptr_t
        getReturnAddress(const MachineContext *context) noexcept
        {
            const auto frameAddress = getFrameAddress(context);
            return reinterpret_cast<const StackFrame *>(frameAddress)->returnAddress;
        }

/**
 * Returns the contents of the link register from the specified machine context.
 * The link register is used on some CPU architectures to store a return address.
 *
 * @param context Machine context to get link register value from.
 * @return Contents of the link register.
 */
#    if CPU(ARM64) || CPU(ARM)
        ALWAYS_INLINE std::uintptr_t
        getLinkRegister(const MachineContext *context) noexcept
        {
            // https://stackoverflow.com/a/8236974
            return context->__ss.__lr;
#    else
        ALWAYS_INLINE std::uintptr_t
        getLinkRegister(__unused const MachineContext *context) noexcept
        {
            return 0;
#    endif
        }

        /**
         * Returns the contents of the program counter from the specified machine context.
         *
         * @param context Machine context to get the program counter value from.
         * @return Contents of the program counter.
         */
        ALWAYS_INLINE std::uintptr_t
        getProgramCounter(const MachineContext *context) noexcept
        {
#    if CPU(ARM64) || CPU(ARM)
            return context->__ss.__pc;
#    elif CPU(X86_64)
            return context->__ss.__rip;
#    elif CPU(X86)
        return context->__ss.__eip;
#    else
#        error Unsupported architecture!
#    endif
        }

        /**
         * Returns the address of the instruction that comes before `address`.
         *
         * In some cases the return address that we read from the stack frame might
         * be for a different symbol, so this function is used to get the address of
         * the previous instruction to make sure we get the call address.
         *
         * More details here: https://reviews.llvm.org/D29992
         *
         * @param address The address to get the previous address relative to.
         *
         * @return The address that comes before `address`.
         */
        ALWAYS_INLINE std::uintptr_t
        getPreviousInstructionAddress(std::uintptr_t address)
        {
            // From
            // https://github.com/llvm-mirror/compiler-rt/blob/master/lib/sanitizer_common/sanitizer_stacktrace.h#L75-L91
            //
            // Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
            // See https://llvm.org/LICENSE.txt for license information.
            // SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#    if CPU(ARM)
            // T32 (Thumb) branch instructions might be 16 or 32 bit long,
            // so we return (pc-2) in that case in order to be safe.
            // For A32 mode we return (pc-4) because all instructions are 32 bit long.
            return (address - 3) & (~1);
#    elif CPU(ARM64)
            // PCs are always 4 byte aligned.
            return address - 4;
#    elif CPU(X86_64) || CPU(X86)
        return address - 1;
#    else
#        error Unsupported architecture!
#    endif
        }

    } // namespace thread
} // namespace profiling
} // namespace sentry

#endif
