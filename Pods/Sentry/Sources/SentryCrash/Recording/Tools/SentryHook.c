#include "SentryHook.h"
#include "SentryCrashMemory.h"
#include "SentryCrashStackCursor.h"
#include "fishhook.h"
#include <dispatch/dispatch.h>
#include <execinfo.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdlib.h>

static bool hooks_active = true;

void
sentrycrash__async_backtrace_incref(sentrycrash_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    __atomic_fetch_add(&bt->refcount, 1, __ATOMIC_SEQ_CST);
}

void
sentrycrash_async_backtrace_decref(sentrycrash_async_backtrace_t *bt)
{
    if (!bt) {
        return;
    }
    if (__atomic_fetch_add(&bt->refcount, -1, __ATOMIC_SEQ_CST) == 1) {
        sentrycrash_async_backtrace_decref(bt->async_caller);
        free(bt);
    }
}

/**
 * This is a poor-mans concurrent hashtable.
 * We have N slots, using a simple FNV-like hashing function on the mach-thread id.
 *
 * *Writes* to a slot will only ever happen using the *current* thread. See
 * the `set`/`unset` functions for SAFETY descriptions.
 * *Reads* will mostly happen on the *current* thread as well, but might happen
 * across threads through `sentrycrashsc_initWithMachineContext`. See the `get`
 * function for possible UNSAFETY.
 *
 * We use a fixed number of slots and do not account for collisions, so a high
 * number of threads might lead to loss of async caller information.
 */

#define SENTRY_MAX_ASYNC_THREADS (128 - 1)

typedef struct {
    SentryCrashThread thread;
    sentrycrash_async_backtrace_t *backtrace;
} sentrycrash_async_caller_slot_t;

static sentrycrash_async_caller_slot_t sentry_async_callers[SENTRY_MAX_ASYNC_THREADS] = { 0 };

static size_t
sentrycrash__thread_idx(SentryCrashThread thread)
{
    // This uses the same magic numbers as FNV, but rather follows the simpler
    // `(x * b + c) mod n` hashing scheme. Also note that `SentryCrashThread`
    // is a typedef for a mach thread id, which is different from a `pthread_t`
    // and should have a better distribution itself.
    return (thread * 0x100000001b3 + 0xcbf29ce484222325) % SENTRY_MAX_ASYNC_THREADS;
}

sentrycrash_async_backtrace_t *
sentrycrash_get_async_caller_for_thread(SentryCrashThread thread)
{
    if (!__atomic_load_n(&hooks_active, __ATOMIC_RELAXED)) {
        return NULL;
    }

    size_t idx = sentrycrash__thread_idx(thread);
    sentrycrash_async_caller_slot_t *slot = &sentry_async_callers[idx];
    if (__atomic_load_n(&slot->thread, __ATOMIC_ACQUIRE) == thread) {
        sentrycrash_async_backtrace_t *backtrace
            = __atomic_load_n(&slot->backtrace, __ATOMIC_RELAXED);
        // UNSAFETY WARNING: There is a tiny chance of use-after-free here.
        // This call can happen across threads, and the thread that "owns" the
        // slot can decref and free the backtrace before *this* thread gets a
        // chance to incref.
        // The only codepath where this happens across threads is as part of
        // `sentrycrashsc_initWithMachineContext` which is always done after a
        // `sentrycrashmc_suspendEnvironment` or as part of
        // `sentrycrashreport_writeStandardReport` which does lack such a guard.
        sentrycrash__async_backtrace_incref(backtrace);
        return backtrace;
    }
    return NULL;
}

static void
sentrycrash__set_async_caller(sentrycrash_async_backtrace_t *backtrace)
{
    SentryCrashThread thread = sentrycrashthread_self();

    size_t idx = sentrycrash__thread_idx(thread);
    sentrycrash_async_caller_slot_t *slot = &sentry_async_callers[idx];

    SentryCrashThread expected = (SentryCrashThread)NULL;
    bool success = __atomic_compare_exchange_n(
        &slot->thread, &expected, thread, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);

    // SAFETY: While multiple threads can race on a "set" call to the same slot,
    // the cmpxchg makes sure that only one thread succeeds
    if (success) {
        __atomic_store_n(&slot->backtrace, backtrace, __ATOMIC_RELEASE);
    }
}

static void
sentrycrash__unset_async_caller(sentrycrash_async_backtrace_t *backtrace)
{
    SentryCrashThread thread = sentrycrashthread_self();

    size_t idx = sentrycrash__thread_idx(thread);
    sentrycrash_async_caller_slot_t *slot = &sentry_async_callers[idx];

    // SAFETY: The condition makes sure that the current thread *owns* this slot.
    if (__atomic_load_n(&slot->thread, __ATOMIC_ACQUIRE) == thread) {
        __atomic_store_n(&slot->backtrace, NULL, __ATOMIC_RELAXED);
        __atomic_store_n(&slot->thread, (SentryCrashThread)NULL, __ATOMIC_RELEASE);
    }

    sentrycrash_async_backtrace_decref(backtrace);
}

sentrycrash_async_backtrace_t *
sentrycrash__async_backtrace_capture(void)
{
    sentrycrash_async_backtrace_t *bt = malloc(sizeof(sentrycrash_async_backtrace_t));
    bt->refcount = 1;

    bt->len = backtrace(bt->backtrace, MAX_BACKTRACE_FRAMES);

    SentryCrashThread thread = sentrycrashthread_self();
    bt->async_caller = sentrycrash_get_async_caller_for_thread(thread);

    return bt;
}

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
        sentrycrash__set_async_caller(bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentrycrash__unset_async_caller(bt);
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
        sentrycrash__set_async_caller(bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentrycrash__unset_async_caller(bt);
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
        sentrycrash__set_async_caller(bt);

        // call through to the original block
        block();

        // and decref our current backtrace
        sentrycrash__unset_async_caller(bt);
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
