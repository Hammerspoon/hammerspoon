#include <unistd.h>

// write(2) is async signal safe:
// http://man7.org/linux/man-pages/man7/signal-safety.7.html
#define __SENTRY_LOG_ASYNC_SAFE(fd, str) write(fd, str, sizeof(str) - 1)
#define SENTRY_LOG_ASYNC_SAFE_INFO(str) __SENTRY_LOG_ASYNC_SAFE(STDOUT_FILENO, str "\n")
#define SENTRY_LOG_ASYNC_SAFE_ERROR(str) __SENTRY_LOG_ASYNC_SAFE(STDERR_FILENO, str "\n")
