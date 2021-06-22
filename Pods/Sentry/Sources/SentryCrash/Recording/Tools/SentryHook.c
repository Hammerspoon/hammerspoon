#include "SentryHook.h"
#include "fishhook.h"
#include <dispatch/dispatch.h>
#include <execinfo.h>
#include <mach/mach.h>
#include <pthread.h>

// NOTE on accessing thread-locals across threads:
// We save the async stacktrace as a thread local when dispatching async calls,
// but the various crash handlers need to access these thread-locals across threads
// sometimes, which we do here:
// While `pthread_t` is an opaque type, the offset of `thread specific data` (tsd)
// is fixed due to backwards compatibility.
// See:
// https://github.com/apple/darwin-libpthread/blob/c60d249cc84dfd6097a7e71c68a36b47cbe076d1/src/types_internal.h#L409-L432

#if __LP64__
#    define TSD_OFFSET 224
#else
#    define TSD_OFFSET 176
#endif

static pthread_key_t async_caller_key = 0;

sentrycrash_async_backtrace_t *
sentrycrash_get_async_caller_for_thread(SentryCrashThread thread)
{
    return NULL;

    // TODO: Disabled because still experimental.
    //    const pthread_t pthread = pthread_from_mach_thread_np((thread_t)thread);
    //    void **tsd_slots = (void *)((uint8_t *)pthread + TSD_OFFSET);
    //
    //    return (sentrycrash_async_backtrace_t *)__atomic_load_n(
    //        &tsd_slots[async_caller_key], __ATOMIC_SEQ_CST);
}

void
sentrycrash__async_backtrace_incref(sentrycrash_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    __atomic_fetch_add(&bt->refcount, 1, __ATOMIC_SEQ_CST);
}

void
sentrycrash__async_backtrace_decref(sentrycrash_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    if (__atomic_fetch_add(&bt->refcount, -1, __ATOMIC_SEQ_CST) == 1) {
        sentrycrash__async_backtrace_decref(bt->async_caller);
        free(bt);
    }
}

sentrycrash_async_backtrace_t *
sentrycrash__async_backtrace_capture(void)
{
    sentrycrash_async_backtrace_t *bt = malloc(sizeof(sentrycrash_async_backtrace_t));
    bt->refcount = 1;

    bt->len = backtrace(bt->backtrace, MAX_BACKTRACE_FRAMES);

    sentrycrash_async_backtrace_t *caller = pthread_getspecific(async_caller_key);
    sentrycrash__async_backtrace_incref(caller);
    bt->async_caller = caller;

    return bt;
}

static bool hooks_active = true;

static void (*real_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);

void
sentrycrash__hook_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_async(queue, block);
    }

    // create a backtrace, capturing the async callsite
    sentrycrash_async_backtrace_t *bt = sentrycrash__async_backtrace_capture();

    return real_dispatch_async(queue, ^{
        // inside the async context, save the backtrace in a thread local for later consumption
        pthread_setspecific(async_caller_key, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        pthread_setspecific(async_caller_key, NULL);
        sentrycrash__async_backtrace_decref(bt);
    });
}

static void (*real_dispatch_async_f)(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);

void
sentrycrash__hook_dispatch_async_f(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_async_f(queue, context, work);
    }
    sentrycrash__hook_dispatch_async(queue, ^{ work(context); });
}

static void (*real_dispatch_after)(
    dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);

void
sentrycrash__hook_dispatch_after(
    dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_after(when, queue, block);
    }

    // create a backtrace, capturing the async callsite
    sentrycrash_async_backtrace_t *bt = sentrycrash__async_backtrace_capture();

    return real_dispatch_after(when, queue, ^{
        // inside the async context, save the backtrace in a thread local for later consumption
        pthread_setspecific(async_caller_key, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        pthread_setspecific(async_caller_key, NULL);
        sentrycrash__async_backtrace_decref(bt);
    });
}

static void (*real_dispatch_after_f)(dispatch_time_t when, dispatch_queue_t queue,
    void *_Nullable context, dispatch_function_t work);

void
sentrycrash__hook_dispatch_after_f(
    dispatch_time_t when, dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_after_f(when, queue, context, work);
    }
    sentrycrash__hook_dispatch_after(when, queue, ^{ work(context); });
}

static void (*real_dispatch_barrier_async)(dispatch_queue_t queue, dispatch_block_t block);

void
sentrycrash__hook_dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_barrier_async(queue, block);
    }

    // create a backtrace, capturing the async callsite
    sentrycrash_async_backtrace_t *bt = sentrycrash__async_backtrace_capture();

    return real_dispatch_barrier_async(queue, ^{
        // inside the async context, save the backtrace in a thread local for later consumption
        pthread_setspecific(async_caller_key, bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        pthread_setspecific(async_caller_key, NULL);
        sentrycrash__async_backtrace_decref(bt);
    });
}

static void (*real_dispatch_barrier_async_f)(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work);

void
sentrycrash__hook_dispatch_barrier_async_f(
    dispatch_queue_t queue, void *_Nullable context, dispatch_function_t work)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return real_dispatch_barrier_async_f(queue, context, work);
    }
    sentrycrash__hook_dispatch_barrier_async(queue, ^{ work(context); });
}

static bool hooks_installed = false;

void
sentrycrash_install_async_hooks(void)
{
    __atomic_store_n(&hooks_active, true, __ATOMIC_RELAXED);

    if (__atomic_exchange_n(&hooks_installed, true, __ATOMIC_SEQ_CST)) {
        return;
    }
    if (pthread_key_create(&async_caller_key, NULL) != 0) {
        return;
    }

    sentrycrash__hook_rebind_symbols(
        (struct rebinding[6]) {
            { "dispatch_async", sentrycrash__hook_dispatch_async, (void *)&real_dispatch_async },
            { "dispatch_async_f", sentrycrash__hook_dispatch_async_f,
                (void *)&real_dispatch_async_f },
            { "dispatch_after", sentrycrash__hook_dispatch_after, (void *)&real_dispatch_after },
            { "dispatch_after_f", sentrycrash__hook_dispatch_after_f,
                (void *)&real_dispatch_after_f },
            { "dispatch_barrier_async", sentrycrash__hook_dispatch_barrier_async,
                (void *)&real_dispatch_barrier_async },
            { "dispatch_barrier_async_f", sentrycrash__hook_dispatch_barrier_async_f,
                (void *)&real_dispatch_barrier_async_f },
        },
        6);

    // NOTE: We will *not* hook the following functions:
    //
    // - dispatch_async_and_wait
    // - dispatch_async_and_wait_f
    // - dispatch_barrier_async_and_wait
    // - dispatch_barrier_async_and_wait_f
    //
    // Because these functions `will use the stack of the submitting thread` in some cases
    // and our thread tracking logic would do the wrong thing in that case.
    //
    // See:
    // https://github.com/apple/swift-corelibs-libdispatch/blob/f13ea5dcc055e5d2d7c02e90d8c9907ca9dc72e1/private/workloop_private.h#L321-L326
}

void
sentrycrash_deactivate_async_hooks()
{
    // Instead of reverting the rebinding (which is not really possible), we rather
    // deactivate the hooks. They still exist, and still get called, but they will just
    // call through to the real libdispatch functions immediately.
    __atomic_store_n(&hooks_active, false, __ATOMIC_RELAXED);
}
