// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryAsyncSafeLog.c
//
//  Created by Karl Stenerud on 11-06-25.
//
//  Copyright (c) 2011 Karl Stenerud. All rights reserved.
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

#include "SentryAsyncSafeLog.h"
#include "SentryCrashDebug.h"
#include "SentryInternalCDefines.h"

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

// Compiler hints for "if" statements
#define likely_if(x) if (__builtin_expect(x, 1))
#define unlikely_if(x) if (__builtin_expect(x, 0))

/** Write a formatted string to the log.
 *
 * @param fmt The format string, followed by its arguments.
 */
static void writeFmtToLog(const char *fmt, ...);

/** Write a formatted string to the log using a vararg list.
 *
 * @param fmt The format string.
 *
 * @param args The variable arguments.
 */
static void writeFmtArgsToLog(const char *fmt, va_list args);

static inline const char *
lastPathEntry(const char *const path)
{
    const char *lastFile = strrchr(path, '/');
    return lastFile == 0 ? path : lastFile + 1;
}

static inline void
writeFmtToLog(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    writeFmtArgsToLog(fmt, args);
    va_end(args);
}

/** The file descriptor where log entries get written. */
static int g_fd = -1;

#if SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE
static bool g_isDebugging;
static bool g_checkedIsDebugging;
#endif // SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE

static void
writeToLog(const char *const str)
{
    if (g_fd >= 0) {
        int bytesToWrite = (int)strlen(str);
        const char *pos = str;
        while (bytesToWrite > 0) {
            int bytesWritten = (int)write(g_fd, pos, (unsigned)bytesToWrite);
            unlikely_if(bytesWritten == -1) { break; }
            bytesToWrite -= bytesWritten;
            pos += bytesWritten;
        }
    }

#if SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE
    // if we're debugging, also write the log statements to the console; we only check once for
    // performance reasons; if the debugger is attached or detached while running, it will not
    // change console-based logging
    if (!g_checkedIsDebugging) {
        g_checkedIsDebugging = true;
        g_isDebugging = sentrycrashdebug_isBeingTraced();
    }
    if (g_isDebugging) {
        fprintf(stdout, "%s", str);
        fflush(stdout);
    }
#endif // SENTRY_ASYNC_SAFE_LOG_ALSO_WRITE_TO_CONSOLE
}

static inline void
writeFmtArgsToLog(const char *fmt, va_list args)
{
    unlikely_if(fmt == NULL) { writeToLog("(null)"); }
    else
    {
        char buffer[SENTRY_ASYNC_SAFE_LOG_C_BUFFER_SIZE];
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        writeToLog(buffer);
    }
}

static inline void
setLogFD(int fd)
{
    if (g_fd >= 0 && g_fd != STDOUT_FILENO && g_fd != STDERR_FILENO && g_fd != STDIN_FILENO) {
        close(g_fd);
    }
    g_fd = fd;
}

int
sentry_asyncLogSetFileName(const char *filename, bool overwrite)
{
    static int fd = -1;
    if (filename != NULL) {
        int openMask = O_WRONLY | O_CREAT;
        if (overwrite) {
            openMask |= O_TRUNC;
        }
        fd = open(filename, openMask, 0644);
        unlikely_if(fd < 0) { return 1; }
        if (filename != g_logFilename) {
            strncpy(g_logFilename, filename, sizeof(g_logFilename));
        }
    }

    setLogFD(fd);
    return 0;
}

void
sentry_asyncLogC(
    const char *const level, const char *const file, const int line, const char *const fmt, ...)
{
    writeFmtToLog("%s: %s (%u): ", level, lastPathEntry(file), line);
    va_list args;
    va_start(args, fmt);
    writeFmtArgsToLog(fmt, args);
    va_end(args);
    writeToLog("\n");
}
