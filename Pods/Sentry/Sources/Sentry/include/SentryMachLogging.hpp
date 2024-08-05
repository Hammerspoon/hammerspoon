#pragma once

#include "SentryProfilingConditionals.h"
#include <mach/kern_return.h>
#include <mach/message.h>

namespace sentry {

/**
 * Returns a human readable description string for a kernel return code.
 *
 * @param kr The kernel return code to get a description for.
 * @return A string containing the description, or an unknown error message if
 * the error code is not known.
 */
const char *kernelReturnCodeDescription(kern_return_t kr) noexcept;

/**
 * Returns a human readable description string for a mach message return code.
 *
 * @param mr The mach message return code to get a description for.
 * @return A string containing the description, or an unknown error message if
 * the error code is not known.
 */
const char *machMessageReturnCodeDescription(mach_msg_return_t mr) noexcept;

} // namespace sentry

#define SENTRY_ASYNC_SAFE_LOG_KERN_RETURN(statement)                                               \
    ({                                                                                             \
        const kern_return_t __log_kr = statement;                                                  \
        if (__log_kr != KERN_SUCCESS) {                                                            \
            SENTRY_ASYNC_SAFE_LOG_ERROR("%s failed with kern return code: %d, description: %s",    \
                #statement, __log_kr, sentry::kernelReturnCodeDescription(__log_kr));              \
        }                                                                                          \
        __log_kr;                                                                                  \
    })

#define SENTRY_ASYNC_SAFE_LOG_MACH_MSG_RETURN(statement)                                           \
    ({                                                                                             \
        const mach_msg_return_t __log_mr = statement;                                              \
        if (__log_mr != MACH_MSG_SUCCESS) {                                                        \
            SENTRY_ASYNC_SAFE_LOG_ERROR(                                                           \
                "%s failed with mach_msg return code: %d, description: %s", #statement, __log_mr,  \
                sentry::machMessageReturnCodeDescription(__log_mr));                               \
        }                                                                                          \
        __log_mr;                                                                                  \
    })
