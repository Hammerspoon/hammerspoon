// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashStackCursor_Backtrace.h
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
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

#ifndef SentryCrashStackCursor_Backtrace_h
#define SentryCrashStackCursor_Backtrace_h

#import "SentryCrashStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Exposed for other internal systems to use.
 */
typedef struct {
    int skippedEntries;
    int backtraceLength;
    const uintptr_t *backtrace;
} SentryCrashStackCursor_Backtrace_Context;

/** Initialize a stack cursor for an existing backtrace (array of addresses).
 *
 * @param cursor The stack cursor to initialize.
 *
 * @param backtrace The existing backtrace to walk.
 *
 * @param backtraceLength The length of the backtrace.
 *
 * @param skipEntries The number of stack entries to skip.
 */
void sentrycrashsc_initWithBacktrace(SentryCrashStackCursor *cursor, const uintptr_t *backtrace,
    int backtraceLength, int skipEntries);

#ifdef __cplusplus
}
#endif

#endif // SentryCrashStackCursor_Backtrace_h
