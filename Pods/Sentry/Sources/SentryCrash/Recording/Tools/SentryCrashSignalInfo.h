// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashSignalInfo.h
//
//  Created by Karl Stenerud on 2012-02-03.
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

/* Information about the signals we are interested in for a crash reporter.
 */

#ifndef HDR_SentryCrashSignalInfo_h
#define HDR_SentryCrashSignalInfo_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/** Get the name of a signal.
 *
 * @param signal The signal.
 *
 * @return The signal's name or NULL if not found.
 */
const char *sentrycrashsignal_signalName(int signal);

/** Get the name of a signal's subcode.
 *
 * @param signal The signal.
 *
 * @param code The signal's code.
 *
 * @return The code's name or NULL if not found.
 */
const char *sentrycrashsignal_signalCodeName(int signal, int code);

/** Get a list of fatal signals.
 *
 * @return A list of fatal signals.
 */
const int *sentrycrashsignal_fatalSignals(void);

/** Get the size of the fatal signals list.
 *
 * @return The size of the fatal signals list.
 */
int sentrycrashsignal_numFatalSignals(void);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashSignalInfo_h
