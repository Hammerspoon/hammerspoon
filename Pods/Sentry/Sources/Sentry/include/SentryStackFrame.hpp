#pragma once

#include "SentryCPU.h"

#include <cstdint>

// These architectures have a downward-growing stack, in order to support other
// architectures, support for upward growing stacks may need to be added.
#if !(CPU(X86) || CPU(X86_64) || CPU(ARM) || CPU(ARM64))
#    error Unsupported architecture!
#endif

namespace sentry {
namespace profiling {
    /**
     * Represents the structure of a stack frame in memory.
     */
    struct __attribute__((packed)) StackFrame {
        /** Pointer to the stack frame of the caller. */
        const StackFrame *const next;
        /** Return address of this stack frame. */
        const std::uintptr_t returnAddress;

        /**
         * Returns whether the specified stack frame pointer is aligned.
         * @param framePtr The frame pointer to check for alignment.
         * @return Whether the pointer is aligned.
         */
        static inline bool
        isAligned(std::uintptr_t framePtr) noexcept
        {
#if CPU(X86_64) || CPU(X86) || CPU(ARM64)
            // x86_64 requires the stack pointer to be aligned to 16 bytes for
            // function calls, even though the minimum alignment is 8 bytes. We
            // enforce the stricter 16 byte alignment here.
            // Reference: https://stackoverflow.com/a/5540149
            //
            // An earlier version of the i386 ABI only required 4-byte alignment,
            // but a later revision changed this to 16-byte, which is enforced in
            // GCC >= 4.5.
            // Reference: https://en.wikipedia.org/wiki/X86_calling_conventions
            // Reference: https://stackoverflow.com/a/40325384
            //
            // ARM64 is the same -- 8 byte minimum, 16 bytes for function calls:
            // https://community.arm.com/developer/ip-products/processors/b/processors-ip-blog/posts/using-the-stack-in-aarch64-implementing-push-and-pop
            return (framePtr & 0xf) == 0;
#elif CPU(ARM)
            // ARM requires 8 byte alignment for external interfaces (function calls)
            // http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.faqs/ka4127.html
            return (framePtr & 0xf) == 8;
#endif
        }

        /**
         * Returns whether the specified stack frame pointer is aligned.
         * @param framePtr The frame pointer to check for alignment.
         * @return Whether the pointer is aligned.
         */
        static inline bool
        isAligned(StackFrame *framePtr)
        {
            return isAligned(reinterpret_cast<std::uintptr_t>(framePtr));
        }
    };

    static_assert(sizeof(StackFrame) == (sizeof(std::uintptr_t) * 2),
        "The size of a StackFrame must be 2 times the pointer width");

} // namespace profiling
} // namespace sentry
