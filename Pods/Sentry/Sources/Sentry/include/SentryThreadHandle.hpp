#pragma once

#include "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryStackBounds.hpp"

#    include <chrono>
#    include <cstdint>
#    include <mach/mach.h>
#    include <memory>
#    include <pthread.h>
#    include <string>
#    include <type_traits>
#    include <utility>
#    include <vector>

/**
 * Threading helpers for Darwin-based platforms.
 */
namespace sentry {
namespace profiling {
    namespace thread {
        using TIDType = std::uint64_t;
    } // namespace thread

    enum class ThreadRunState { Undefined, Running, Stopped, Waiting, Uninterruptible, Halted };

    struct ThreadCPUInfo {
        /** User run time in microseconds. */
        std::chrono::microseconds userTimeMicros;
        /** System run time in microseconds. */
        std::chrono::microseconds systemTimeMicros;
        /** CPU usage percentage from 0.0 to 1.0. */
        float usagePercent;
        /** Current run state of the thread. */
        ThreadRunState runState;
        /** Whether the thread is idle or not. */
        bool idle;
    };

    class ThreadHandle {
    public:
        using NativeHandle = thread_t;

        static_assert(
            std::is_fundamental<NativeHandle>::value, "NativeHandle must be a fundamental type");

        /**
         * Constructs a \ref ThreadHandle using a native handle type.
         * @param handle The native thread handle.
         */
        explicit ThreadHandle(NativeHandle handle) noexcept;

        /**
         * @return A handle to the currently executing thread, which is acquired
         * in a non async-signal-safe manner.
         */
        static std::unique_ptr<ThreadHandle> current() noexcept;

        /**
         * @return A vector of handles for all of the threads in the current process.
         */
        static std::vector<std::unique_ptr<ThreadHandle>> all() noexcept;

        /**
         * @return A pair, where the first element is a vector of handles for all of
         * the threads in the current process, excluding the current thread (the
         * thread that this function is being called on), and the second element
         * is a handle to the current thread.
         */
        static std::pair<std::vector<std::unique_ptr<ThreadHandle>>, std::unique_ptr<ThreadHandle>>
        allExcludingCurrent() noexcept;

        /**
         * @param handle The native handle to get the TID from.
         * @return The TID of the thread that the native handle represents.
         */
        static thread::TIDType tidFromNativeHandle(NativeHandle handle);

        /**
         * @return The underlying native thread handle.
         */
        NativeHandle nativeHandle() const noexcept;

        /**
         * @return The ID of the thread.
         */
        thread::TIDType tid() const noexcept;

        /**
         * @return The name of the thread, or an empty string if the thread doesn't
         * have a name, or if there was failure in acquiring the name.
         *
         * @warning This function is not async-signal safe!
         */
        std::string name() const noexcept;

        /**
         * @return The address of the dispatch queue currently associated with
         * the thread, or 0 if there is no valid queue. This function checks if
         * the memory at the returned address is readable, but there is no guarantee
         * that the queue will continue to stay valid by the time you deference it,
         * as queue deallocation can happen concurrently.
         *
         * @warning This function is not async-signal safe!
         */
        std::uint64_t dispatchQueueAddress() const noexcept;

        /**
         * @return The priority of the specified thread, or -1 if the thread priority
         * could not be successfully determined.
         *
         * @warning This function is not async-signal safe!
         */
        int priority() const noexcept;

        /**
         * @return CPU usage information for the thread.
         */
        ThreadCPUInfo cpuInfo() const noexcept;

        /**
         * @return Whether the thread is currently idle.
         */
        bool isIdle() const noexcept;

        /**
         * @return The bounds of the thread's stack (start, end)
         *
         * @warning This function is not async-signal safe!
         */
        StackBounds stackBounds() const noexcept;

        /**
         * Suspends the thread, incrementing the suspend counter.
         * @return Whether the thread was successfully suspended.
         */
        bool suspend() const noexcept;

        /**
         * Resumes the thread, decrementing the suspend counter.
         * @return Whether the thread was successfully resumed.
         */
        bool resume() const noexcept;

        bool operator==(const ThreadHandle &other) const;

        ~ThreadHandle();
        ThreadHandle(const ThreadHandle &) = delete;
        ThreadHandle &operator=(const ThreadHandle &) = delete;

    private:
        NativeHandle handle_;
        bool isOwnedPort_;
        mutable pthread_t pthreadHandle_;

        ThreadHandle(NativeHandle handle, bool isOwnedPort) noexcept;
        pthread_t pthreadHandle() const noexcept;
    };

} // namespace profiling
} // namespace sentry

#endif
