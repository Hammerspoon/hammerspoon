#pragma once

#include "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryStackBounds.hpp"
#    include "SentryThreadHandle.hpp"
#    include "SentryThreadMetadataCache.hpp"

#    include <cstddef>
#    include <cstdint>
#    include <functional>
#    include <memory>
#    include <vector>

namespace sentry {
namespace profiling {

    struct StackBounds;

    struct Backtrace {
        ThreadMetadata threadMetadata;
        std::uint64_t absoluteTimestamp;
        std::vector<std::uintptr_t> addresses;
    };

    /**
     * Async-signal-safe implementation of backtrace(3), collects a backtrace
     * for the current thread.
     *
     * @param targetThread The thread that a backtrace should be captured for.
     * @param callingThread The thread that is calling this function -- pass ThreadHandle::current()
     * @param addresses A pointer to a buffer to store addresses in to.
     * @param bounds The bounds of the stack for the current thread.
     * @param reachedEndOfStackPtr Pointer to a bool to be set indicating whether the stack
     * traversal reached the end of the stack. If this is `false`, then that means there were
     * additional frames that were not recorded because the `maxDepth` was too small.
     * @param maxDepth The maximum number of addresses to collect, this should
     * be less than or equal to the size of the buffer.
     * @param skip An optional number of stack frames to skip at the beginning.
     *
     * @return The actual number of addresses collected. Returns 0 if a backtrace
     * could not be collected.
     */
    NOT_TAIL_CALLED NEVER_INLINE std::size_t backtrace(const ThreadHandle &targetThread,
        const ThreadHandle &callingThread, std::uintptr_t *addresses, const StackBounds &bounds,
        bool *reachedEndOfStackPtr, std::size_t maxDepth, std::size_t skip = 0) noexcept;

    /**
     * Attempts to collect backtraces for every thread in the process, except the
     * thread that this function is being called on. Calls `f` with an entry object
     * containing the backtrace data for each thread. The entry object should NOT be used
     * outside, the scope of the callback, as it will be invalid or reused for a subsequent
     * call.
     *
     * @param f The function to call for each entry.
     * @param cache The cache used to look up thread metadata.
     */
    void enumerateBacktracesForAllThreads(const std::function<void(const Backtrace &)> &f,
        const std::shared_ptr<ThreadMetadataCache> &cache);

} // namespace profiling
} // namespace sentry

#endif
