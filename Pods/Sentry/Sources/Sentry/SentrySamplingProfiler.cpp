#include "SentrySamplingProfiler.hpp"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    include "SentryAsyncSafeLog.h"
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
        struct SamplingThreadParams {
            mach_port_t port;
            clock_serv_t clock;
            mach_timespec_t delaySpec;
            std::shared_ptr<ThreadMetadataCache> cache;
            std::function<void(const Backtrace &)> callback;
            std::atomic_uint64_t &numSamples;
            std::function<void()> onThreadStart;
        };

        void
        freeReplyBuf(void *reply)
        {
            free(reply);
        }

        void
        deleteParams(void *params)
        {
            delete reinterpret_cast<SamplingThreadParams *>(params);
        }

        void *
        samplingThreadMain(void *arg)
        {
            SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(pthread_setname_np("io.sentry.SamplingProfiler"));
            const auto params = reinterpret_cast<SamplingThreadParams *>(arg);
            if (params->onThreadStart != nullptr) {
                params->onThreadStart();
            }
            const int maxSize = 512;
            const auto replyBuf = reinterpret_cast<mig_reply_error_t *>(malloc(maxSize));
            pthread_cleanup_push(freeReplyBuf, replyBuf);
            pthread_cleanup_push(deleteParams, params);
            while (true) {
                pthread_testcancel();
                if (SENTRY_ASYNC_SAFE_LOG_MACH_MSG_RETURN(mach_msg(&replyBuf->Head, MACH_RCV_MSG, 0,
                        maxSize, params->port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL))
                    != MACH_MSG_SUCCESS) {
                    break;
                }
                if (SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(
                        clock_alarm(params->clock, TIME_RELATIVE, params->delaySpec, params->port))
                    != KERN_SUCCESS) {
                    break;
                }

                params->numSamples.fetch_add(1, std::memory_order_relaxed);
                enumerateBacktracesForAllThreads(params->callback, params->cache);
            }
            pthread_cleanup_pop(1);
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
        if (SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(
                host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &clock_))
            != KERN_SUCCESS) {
            return;
        }
        if (SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(
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
        SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(
            mach_port_mod_refs(mach_task_self(), port_, MACH_PORT_RIGHT_RECEIVE, -1));
    }

    void
    SamplingProfiler::startSampling(std::function<void()> onThreadStart)
    {
        if (!isInitialized_) {
            SENTRY_ASYNC_SAFE_LOG_WARN(
                "startSampling is no-op because SamplingProfiler failed to initialize");
            return;
        }
        std::lock_guard<std::mutex> l(isSamplingLock_);
        if (isSampling_) {
            return;
        }
        isSampling_ = true;
        numSamples_ = 0;
        pthread_attr_t attr;
        if (SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(pthread_attr_init(&attr)) != 0) {
            return;
        }
        sched_param param;
        if (SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(pthread_attr_getschedparam(&attr, &param)) == 0) {
            // A priority of 50 is higher than user input, according to:
            // https://chromium.googlesource.com/chromium/src/base/+/master/threading/platform_thread_mac.mm#302
            // Run at a higher priority than the main thread so that we can capture main thread
            // backtraces even when it's busy.
            param.sched_priority = 50;
            SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(pthread_attr_setschedparam(&attr, &param));
        }

        const auto params = new SamplingThreadParams { port_, clock_, delaySpec_, cache_, callback_,
            std::ref(numSamples_), std::move(onThreadStart) };
        if (SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(
                pthread_create(&thread_, &attr, samplingThreadMain, params))
            != 0) {
            delete params;
            return;
        }

        SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(clock_alarm(clock_, TIME_RELATIVE, delaySpec_, port_));
    }

    void
    SamplingProfiler::stopSampling()
    {
        if (!isInitialized_) {
            return;
        }
        std::lock_guard<std::mutex> l(isSamplingLock_);
        if (!isSampling_) {
            return;
        }
        SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(pthread_cancel(thread_));
        SENTRY_ASYNC_SAFE_LOG_ERRNO_RETURN(pthread_join(thread_, NULL));
        isSampling_ = false;
    }

    bool
    SamplingProfiler::isSampling()
    {
        std::lock_guard<std::mutex> l(isSamplingLock_);
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
