//
//  SentryCrashMach.h
//
// Copyright 2016 Karl Stenerud.
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

#ifndef HDR_SentryCrashMach_h
#define HDR_SentryCrashMach_h

#ifdef __cplusplus
extern "C" {
#endif


#include <stdint.h>

/** Get the name of a mach exception.
 *
 * @param exceptionType The exception type.
 *
 * @return The exception's name or NULL if not found.
 */
const char* sentrycrashmach_exceptionName(int64_t exceptionType);

/** Get the name of a mach kernel return code.
 *
 * @param returnCode The return code.
 *
 * @return The code's name or NULL if not found.
 */
const char* sentrycrashmach_kernelReturnCodeName(int64_t returnCode);

/** Get the signal equivalent of a mach exception.
 *
 * @param exception The mach exception.
 *
 * @param code The mach exception code.
 *
 * @return The matching signal, or 0 if not found.
 */
int sentrycrashmach_signalForMachException(int exception, int64_t code);

/** Get the mach exception equivalent of a signal.
 *
 * @param signal The signal.
 *
 * @return The matching mach exception, or 0 if not found.
 */
int sentrycrashmach_machExceptionForSignal(int signal);


#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMach_h
