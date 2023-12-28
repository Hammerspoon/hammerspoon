// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitorType.h
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

#ifndef HDR_SentryCrashMonitorType_h
#define HDR_SentryCrashMonitorType_h

#ifdef __cplusplus
extern "C" {
#endif

/** Various aspects of the system that can be monitored:
 * - Mach kernel exception
 * - Fatal signal
 * - Uncaught C++ exception
 * - Uncaught Objective-C NSException
 */
typedef enum {
    /* Captures and reports Mach exceptions. */
    SentryCrashMonitorTypeMachException = 0x01,

    /* Captures and reports POSIX signals. */
    SentryCrashMonitorTypeSignal = 0x02,

    /* Captures and reports C++ exceptions.
     * Note: This will slightly slow down exception processing.
     */
    SentryCrashMonitorTypeCPPException = 0x04,

    /* Captures and reports NSExceptions. */
    SentryCrashMonitorTypeNSException = 0x08,

    /* Keeps track of and injects system information. */
    SentryCrashMonitorTypeSystem = 0x40,

    /* Keeps track of and injects application state. */
    SentryCrashMonitorTypeApplicationState = 0x80,

} SentryCrashMonitorType;

#define SentryCrashMonitorTypeAll                                                                  \
    (SentryCrashMonitorTypeMachException | SentryCrashMonitorTypeSignal                            \
        | SentryCrashMonitorTypeCPPException | SentryCrashMonitorTypeNSException                   \
        | SentryCrashMonitorTypeSystem | SentryCrashMonitorTypeApplicationState)

#define SentryCrashMonitorTypeDebuggerUnsafe                                                       \
    (SentryCrashMonitorTypeMachException | SentryCrashMonitorTypeSignal                            \
        | SentryCrashMonitorTypeCPPException | SentryCrashMonitorTypeNSException)

#define SentryCrashMonitorTypeAsyncSafe                                                            \
    (SentryCrashMonitorTypeMachException | SentryCrashMonitorTypeSignal)

#define SentryCrashMonitorTypeAsyncUnsafe                                                          \
    (SentryCrashMonitorTypeAll & (~SentryCrashMonitorTypeAsyncSafe))

/** Monitors that are safe to enable in a debugger. */
#define SentryCrashMonitorTypeDebuggerSafe                                                         \
    (SentryCrashMonitorTypeAll & (~SentryCrashMonitorTypeDebuggerUnsafe))

/** Monitors that are safe to use in a production environment.
 * All other monitors should be considered experimental.
 */
#define SentryCrashMonitorTypeProductionSafe (SentryCrashMonitorTypeAll)

/** Production safe monitors */
#define SentryCrashMonitorTypeProductionSafeMinimal (SentryCrashMonitorTypeProductionSafe)

/** Monitors that are required for proper operation.
 * These add essential information to the reports, but do not trigger reporting.
 */
#define SentryCrashMonitorTypeRequired                                                             \
    (SentryCrashMonitorTypeSystem | SentryCrashMonitorTypeApplicationState)

#define SentryCrashMonitorTypeNone 0

const char *sentrycrashmonitortype_name(SentryCrashMonitorType monitorType);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMonitorType_h
