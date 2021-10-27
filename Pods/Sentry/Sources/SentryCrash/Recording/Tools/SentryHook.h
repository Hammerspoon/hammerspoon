#ifndef SENRTY_HOOK_h
#define SENRTY_HOOK_h

#include "SentryCrashThread.h"
#include <stdint.h>

#define MAX_BACKTRACE_FRAMES 128

/**
 * This represents a stacktrace that can optionally have an `async_caller` and form an async call
 * chain.
 */
typedef struct sentrycrash_async_backtrace_s sentrycrash_async_backtrace_t;
struct sentrycrash_async_backtrace_s {
    size_t refcount;
    sentrycrash_async_backtrace_t *async_caller;
    size_t len;
    void *backtrace[MAX_BACKTRACE_FRAMES];
};

/**
 * Returns the async caller of the current calling context, if any.
 * The async stacktrace returned has an owned reference, so it needs to be freed using
 * `sentrycrash_async_backtrace_decref`.
 */
sentrycrash_async_backtrace_t *sentrycrash_get_async_caller_for_thread(SentryCrashThread);

/** Decrements the refcount on the given `bt`. */
void sentrycrash_async_backtrace_decref(sentrycrash_async_backtrace_t *bt);

/**
 * Installs the various async hooks that sentry offers.
 *
 * The hooks work like this:
 * We overwrite the `libdispatch/dispatch_async`, etc functions with our own wrapper.
 * Those wrappers create a stacktrace in the calling thread, and pass that stacktrace via a closure
 * into the callee thread. In the callee, the stacktrace is saved as a thread-local before invoking
 * the original block/function. The thread local can be accessed for inspection and is also used for
 * chained async calls.
 */
void sentrycrash_install_async_hooks(void);

/**
 * Deactivates the previously installed hooks.
 *
 * It is not really possible to uninstall the previously installed hooks, so we rather just
 * deactivate them.
 */
void sentrycrash_deactivate_async_hooks(void);

#endif /* SENRTY_HOOK_h */
