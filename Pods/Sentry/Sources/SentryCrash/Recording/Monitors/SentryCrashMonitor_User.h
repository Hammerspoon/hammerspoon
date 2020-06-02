//
//  SentryCrashMonitor_User.h
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

#ifndef HDR_SentryCrashMonitor_User_h
#define HDR_SentryCrashMonitor_User_h

#ifdef __cplusplus
extern "C" {
#endif


#include "SentryCrashMonitor.h"

#include <stdbool.h>


/** Report a custom, user defined exception.
 * If terminateProgram is true, all sentries will be uninstalled and the application will
 * terminate with an abort().
 *
 * @param name The exception name (for namespacing exception types).
 *
 * @param reason A description of why the exception occurred.
 *
 * @param language A unique language identifier.
 *
 * @param lineOfCode A copy of the offending line of code (NULL = ignore).
 *
 * @param stackTrace JSON encoded array containing stack trace information (one frame per array entry).
 *                   The frame structure can be anything you want, including bare strings.
 *
 * @param logAllThreads If true, suspend all threads and log their state. Note that this incurs a
 *                      performance penalty, so it's best to use only on fatal errors.
 *
 * @param terminateProgram If true, do not return from this function call. Terminate the program instead.
 */
void sentrycrashcm_reportUserException(const char* name,
                              const char* reason,
                              const char* language,
                              const char* lineOfCode,
                              const char* stackTrace,
                              bool logAllThreads,
                              bool terminateProgram);

/** Access the Monitor API.
 */
SentryCrashMonitorAPI* sentrycrashcm_user_getAPI(void);


#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMonitor_User_h
