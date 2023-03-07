#include "SentrySamplingProfiler.hpp"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryBacktrace.hpp"
#    include "SentryMachLogging.hpp"
#    include "SentryThreadMetadataCache.hpp"

#    include <chrono>
#    include <mach/clock.h>
#    include <mach/clock_reply.h>
#    include <mach/clock_types.h>
#    include <malloc/_malloc.h>
#    include <pthread.h>

namespace sentry {
namespace profiling {
    namespace {
        void
        samplingThreadCleanup(void *buf)
        {
            free(buf);
        }

        void *
        samplingThreadMain(mach_port_t port, clock_serv_t clock, mach_timespec_t delaySpec,
            std::shared_ptr<ThreadMetadataCache> cache,
            std::function<void(const Backtrace &)> callback, std::atomic_uint64_t &numSamples,
            std::function<void()> onThreadStart)
        {
            SENTRY_PROF_LOG_ERROR_RETURN(pthread_setname_np("io.sentry.SamplingProfiler"));
            const int maxSize = 512;
            const auto bufRequest = reinterpret_cast<mig_reply_error_t *>(malloc(maxSize));
            if (onThreadStart) {
                onThreadStart();
            }
            pthread_cleanup_push(samplingThreadCleanup, bufRequest);
            while (true) {
                pthread_testcancel();
                if (SENTRY_PROF_LOG_MACH_MSG_RETURN(mach_msg(&bufRequest->Head, MACH_RCV_MSG, 0,
                        maxSize, port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL))
                    != MACH_MSG_SUCCESS) {
                    break;
                }
                if (SENTRY_PROF_LOG_KERN_RETURN(clock_alarm(clock, TIME_RELATIVE, delaySpec, port))
                    != KERN_SUCCESS) {
                    break;
                }

                numSamples.fetch_add(1, std::memory_order_relaxed);
                enumerateBacktracesForAllThreads(callback, cache);
            }
            pthread_cleanup_pop(1);
            return nullptr;
        }

    } // namespace

    SamplingProfiler::SamplingProfiler(
        std::function<void(const Backtrace &)> callback, std::uint32_t samplingRateHz)
        : callback_(std::move(callback))
        , cache_(std::make_shared<ThreadMetadataCache>())
        , isInitialized_(false)
        , isSampling_(false)
        , port_(0)
        , numSamples_(0)
    {
        if (SENTRY_PROF_LOG_KERN_RETURN(
                host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &clock_))
            != KERN_SUCCESS) {
            return;
        }
        if (SENTRY_PROF_LOG_KERN_RETURN(
                mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port_))
            != KERN_SUCCESS) {
            return;
        }
        const auto intervalNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::duration<float>(1) / samplingRateHz)
                                    .count();
        delaySpec_ = { .tv_sec = static_cast<unsigned int>(intervalNs / 1000000000ULL),
            .tv_nsec = static_cast<clock_res_t>(intervalNs % 1000000000ULL) };
        isInitialized_ = true;
    }

    SamplingProfiler::~SamplingProfiler()
    {
        if (!isInitialized_) {
            return;
        }
        stopSampling();
        SENTRY_PROF_LOG_KERN_RETURN(
            mach_port_mod_refs(mach_task_self(), port_, MACH_PORT_RIGHT_RECEIVE, -1));
    }

    void
    SamplingProfiler::startSampling(std::function<void()> onThreadStart)
    {
        if (!isInitialized_) {
            SENTRY_PROF_LOG_WARN(
                "startSampling is no-op because SamplingProfiler failed to initialize");
            return;
        }
        std::lock_guard<std::mutex> l(lock_);
        if (isSampling_) {
            return;
        }
        isSampling_ = true;
        numSamples_ = 0;
        thread_ = std::thread(samplingThreadMain, port_, clock_, delaySpec_, cache_, callback_,
            std::ref(numSamples_), onThreadStart);

        int policy;
        sched_param param;
        const auto pthreadHandle = thread_.native_handle();
        if (SENTRY_PROF_LOG_ERROR_RETURN(pthread_getschedparam(pthreadHandle, &policy, &param))
            == 0) {
            // A priority of 50 is higher than user input, according to:
            // https://chromium.googlesource.com/chromium/src/base/+/master/threading/platform_thread_mac.mm#302
            // Run at a higher priority than the main thread so that we can capture main thread
            // backtraces even when it's busy.
            param.sched_priority = 50;
            SENTRY_PROF_LOG_ERROR_RETURN(pthread_setschedparam(pthreadHandle, policy, &param));
        }

        SENTRY_PROF_LOG_KERN_RETURN(clock_alarm(clock_, TIME_RELATIVE, delaySpec_, port_));
    }

    void
    SamplingProfiler::stopSampling()
    {
        if (!isInitialized_) {
            return;
        }
        std::lock_guard<std::mutex> l(lock_);
        if (!isSampling_) {
            return;
        }
        SENTRY_PROF_LOG_KERN_RETURN(pthread_cancel(thread_.native_handle()));
        thread_.join();
        isSampling_ = false;
    }

    bool
    SamplingProfiler::isSampling()
    {
        std::lock_guard<std::mutex> l(lock_);
        return isSampling_;
    }

    std::uint64_t
    SamplingProfiler::numSamples()
    {
        return numSamples_.load();
    }

} // namespace profiling
} // namespace sentry

#endif
