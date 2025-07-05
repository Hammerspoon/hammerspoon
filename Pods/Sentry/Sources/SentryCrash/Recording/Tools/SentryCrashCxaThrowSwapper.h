// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCxaThrowSwapper.h
//
//  Copyright (c) 2019 YANDEX LLC. All rights reserved.
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

#ifndef SentryCrashCxaThrowSwapper_h
#define SentryCrashCxaThrowSwapper_h

#include <stdbool.h>

#ifdef __cplusplus

#    include <typeinfo>

extern "C" {

typedef void (*cxa_throw_type)(void *, std::type_info *, void (*)(void *));
#else
typedef void (*cxa_throw_type)(void *, void *, void (*)(void *));
#endif

/**
 * Swaps the current C++ exception throw handler with a custom one.
 * This allows intercepting C++ exceptions when they are thrown.
 *
 * When a C++ exception is thrown, the compiler generates a call to __cxa_throw.
 * This function replaces the default __cxa_throw implementation by modifying
 * the dynamic linker, allowing us to intercept all C++ exceptions before they
 * are actually thrown. After processing the exception, it still calls the
 * original __cxa_throw to ensure normal exception handling continues.
 *
 * Internally, it iterates through all loaded dynamic library images and updates
 * the __cxa_throw symbol to point to the new handler. This iteration is necessary
 * because each dynamic library has its own instance of __cxa_throw that needs to
 * be modified to ensure we catch exceptions thrown from any library. The implementation
 * is based on the approach used by Meta's fishhook library, but uses its own
 * implementation to rebind dynamic symbols on iOS and macOS.
 *
 * The implementation is adapted from https://github.com/kstenerud/KSCrash and based on
 * https://github.com/facebook/fishhook.alignas We have a local copy of how the fishhook works in
 * develop-docs/Fishhook-Explanation.md.
 *
 * @param handler The new exception throw handler to install
 * @return 0 if successful
 */
int sentrycrashct_swap_cxa_throw(const cxa_throw_type handler);

/**
 * Unswaps the C++ exception throw handler.
 *
 * @return 0 if successful
 */
int sentrycrashct_unswap_cxa_throw(void);

/**
 * For testing purposes only.
 *
 * Checks if the C++ exception throw handler is swapped.
 *
 * @return true if the C++ exception throw handler is swapped, false otherwise
 */
bool sentrycrashct_is_cxa_throw_swapped(void);

#ifdef __cplusplus
}
#endif

#endif /* SentryCrashCxaThrowSwapper_h */
