#pragma once

#include "SentryCPU.h"
#include "SentryStackFrame.hpp"

#include <cstdint>

// These architectures have a downward-growing stack, in order to support other
// architectures, support for upward growing stacks may need to be added.
#if !(CPU(X86) || CPU(X86_64) || CPU(ARM) || CPU(ARM64))
#    error Unsupported architecture!
#endif

namespace sentry {
namespace profiling {
    /**
     * Represents the bounds of a downward-growing stack.
     */
    struct StackBounds {
        /** Start address of the stack. */
        std::uintptr_t start = 0;
        /** End address of the stack. */
        std::uintptr_t end = 0;

        /**
         * Returns whether the specified frame pointer is within the bounds of the
         * stack.
         * @param framePtr The frame pointer to check.
         * @return Whether the pointer is within the bounds of the stack.
         */
        inline bool
        contains(std::uintptr_t framePtr) const noexcept
        {
            return (framePtr > end) && (framePtr < (start - sizeof(StackFrame)));
        }

        /**
         * Performs a simple consistency check to see if the stack bounds are valid.
         * @return Whether the stack bounds are valid.
         */
        inline bool
        isValid() const noexcept
        {
            return (start != 0) && (end != 0) && (start > end);
        }
    };
} // namespace profiling
} // namespace sentry
