#pragma once

typedef unsigned long long bytes;

/**
 * For disabling the thread sanitizer for a method
 */
#if defined(__has_feature)
#    if __has_feature(thread_sanitizer)
#        define SENTRY_DISABLE_THREAD_SANITIZER(message) __attribute__((no_sanitize("thread")))
#    else
#        define SENTRY_DISABLE_THREAD_SANITIZER(message)
#    endif
#else
#    define SENTRY_DISABLE_THREAD_SANITIZER(message)
#endif

// The following adapted from: https://github.com/kstenerud/KSCrash KSCrashSystemCapabilities.h
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include <TargetConditionals.h>

#ifndef TARGET_OS_VISION
#    define TARGET_OS_VISION 0
#endif

#define SENTRY_HOST_IOS TARGET_OS_IOS
#define SENTRY_HOST_TV TARGET_OS_TV
#define SENTRY_HOST_WATCH TARGET_OS_WATCH
#define SENTRY_HOST_VISION TARGET_OS_VISION
#define SENTRY_HOST_MAC                                                                            \
    (TARGET_OS_MAC && !(TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH || TARGET_OS_VISION))

#if SENTRY_HOST_WATCH
#    define SENTRY_HAS_NSEXTENSION 1
#else
#    define SENTRY_HAS_NSEXTENSION 0
#endif

// Mach APIs are explicitly marked as unavailable in tvOS and watchOS.
// See https://github.com/getsentry/sentry-cocoa/issues/406#issuecomment-1171872518
#if SENTRY_HOST_IOS || SENTRY_HOST_MAC
#    define SENTRY_HAS_MACH 1
#else
#    define SENTRY_HAS_MACH 0
#endif

// signal APIs are explicitly marked as unavailable in watchOS.
// See https://github.com/getsentry/sentry-cocoa/issues/406#issuecomment-1171872518
#if SENTRY_HOST_IOS || SENTRY_HOST_MAC || SENTRY_HOST_TV
#    define SENTRY_HAS_SIGNAL 1
#else
#    define SENTRY_HAS_SIGNAL 0
#endif

#if SENTRY_HOST_MAC || SENTRY_HOST_IOS
#    define SENTRY_HAS_SIGNAL_STACK 1
#else
#    define SENTRY_HAS_SIGNAL_STACK 0
#endif

#if SENTRY_HOST_MAC || SENTRY_HOST_IOS || SENTRY_HOST_TV
#    define SENTRY_HAS_THREADS_API 1
#else
#    define SENTRY_HAS_THREADS_API 0
#endif
