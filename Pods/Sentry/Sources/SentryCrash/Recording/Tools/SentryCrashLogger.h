//
//  SentryCrashLogger.h
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


/**
 * SentryCrashLogger
 * ========
 *
 * Prints log entries to the console consisting of:
 * - Level (Error, Warn, Info, Debug, Trace)
 * - File
 * - Line
 * - Function
 * - Message
 *
 * Allows setting the minimum logging level in the preprocessor.
 *
 * Works in C or Objective-C contexts, with or without ARC, using CLANG or GCC.
 *
 *
 * =====
 * USAGE
 * =====
 *
 * Set the log level in your "Preprocessor Macros" build setting. You may choose
 * TRACE, DEBUG, INFO, WARN, ERROR. If nothing is set, it defaults to ERROR.
 *
 * Example: SentryCrashLogger_Level=WARN
 *
 * Anything below the level specified for SentryCrashLogger_Level will not be compiled
 * or printed.
 *
 *
 * Next, include the header file:
 *
 * #include "SentryCrashLogger.h"
 *
 *
 * Next, call the logger functions from your code (using objective-c strings
 * in objective-C files and regular strings in regular C files):
 *
 * Code:
 *    SentryCrashLOG_ERROR(@"Some error message");
 *
 * Prints:
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21): -[SomeFunction]: Some error message
 *
 * Code:
 *    SentryCrashLOG_INFO(@"Info about %@", someObject);
 *
 * Prints:
 *    2011-07-16 05:44:05.239 TestApp[4473:f803] INFO : SomeClass.m (20): -[SomeFunction]: Info about <NSObject: 0xb622840>
 *
 *
 * The "BASIC" versions of the macros behave exactly like NSLog() or printf(),
 * except they respect the SentryCrashLogger_Level setting:
 *
 * Code:
 *    SentryCrashLOGBASIC_ERROR(@"A basic log entry");
 *
 * Prints:
 *    2011-07-16 05:44:05.916 TestApp[4473:f803] A basic log entry
 *
 *
 * NOTE: In C files, use "" instead of @"" in the format field. Logging calls
 *       in C files do not print the NSLog preamble:
 *
 * Objective-C version:
 *    SentryCrashLOG_ERROR(@"Some error message");
 *
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21): -[SomeFunction]: Some error message
 *
 * C version:
 *    SentryCrashLOG_ERROR("Some error message");
 *
 *    ERROR: SomeClass.c (21): SomeFunction(): Some error message
 *
 *
 * =============
 * LOCAL LOGGING
 * =============
 *
 * You can control logging messages at the local file level using the
 * "SentryCrashLogger_LocalLevel" define. Note that it must be defined BEFORE
 * including SentryCrashLogger.h
 *
 * The SentryCrashLOG_XX() and SentryCrashLOGBASIC_XX() macros will print out based on the LOWER
 * of SentryCrashLogger_Level and SentryCrashLogger_LocalLevel, so if SentryCrashLogger_Level is DEBUG
 * and SentryCrashLogger_LocalLevel is TRACE, it will print all the way down to the trace
 * level for the local file where SentryCrashLogger_LocalLevel was defined, and to the
 * debug level everywhere else.
 *
 * Example:
 *
 * // SentryCrashLogger_LocalLevel, if defined, MUST come BEFORE including SentryCrashLogger.h
 * #define SentryCrashLogger_LocalLevel TRACE
 * #import "SentryCrashLogger.h"
 *
 *
 * ===============
 * IMPORTANT NOTES
 * ===============
 *
 * The C logger changes its behavior depending on the value of the preprocessor
 * define SentryCrashLogger_CBufferSize.
 *
 * If SentryCrashLogger_CBufferSize is > 0, the C logger will behave in an async-safe
 * manner, calling write() instead of printf(). Any log messages that exceed the
 * length specified by SentryCrashLogger_CBufferSize will be truncated.
 *
 * If SentryCrashLogger_CBufferSize == 0, the C logger will use printf(), and there will
 * be no limit on the log message length.
 *
 * SentryCrashLogger_CBufferSize can only be set as a preprocessor define, and will
 * default to 1024 if not specified during compilation.
 */


// ============================================================================
#pragma mark - (internal) -
// ============================================================================


#ifndef HDR_SentryCrashLogger_h
#define HDR_SentryCrashLogger_h

#ifdef __cplusplus
extern "C" {
#endif


#include <stdbool.h>


#ifdef __OBJC__

#import <CoreFoundation/CoreFoundation.h>

void i_sentrycrashlog_logObjC(const char* level,
                     const char* file,
                     int line,
                     const char* function,
                     CFStringRef fmt, ...);

void i_sentrycrashlog_logObjCBasic(CFStringRef fmt, ...);

#define i_SentryCrashLOG_FULL(LEVEL,FILE,LINE,FUNCTION,FMT,...) i_sentrycrashlog_logObjC(LEVEL,FILE,LINE,FUNCTION,(__bridge CFStringRef)FMT,##__VA_ARGS__)
#define i_SentryCrashLOG_BASIC(FMT, ...) i_sentrycrashlog_logObjCBasic((__bridge CFStringRef)FMT,##__VA_ARGS__)

#else // __OBJC__

void i_sentrycrashlog_logC(const char* level,
                  const char* file,
                  int line,
                  const char* function,
                  const char* fmt, ...);

void i_sentrycrashlog_logCBasic(const char* fmt, ...);

#define i_SentryCrashLOG_FULL i_sentrycrashlog_logC
#define i_SentryCrashLOG_BASIC i_sentrycrashlog_logCBasic

#endif // __OBJC__


/* Back up any existing defines by the same name */
#ifdef SentryCrash_NONE
    #define SentryCrashLOG_BAK_NONE SentryCrash_NONE
    #undef SentryCrash_NONE
#endif
#ifdef ERROR
    #define SentryCrashLOG_BAK_ERROR ERROR
    #undef ERROR
#endif
#ifdef WARN
    #define SentryCrashLOG_BAK_WARN WARN
    #undef WARN
#endif
#ifdef INFO
    #define SentryCrashLOG_BAK_INFO INFO
    #undef INFO
#endif
#ifdef DEBUG
    #define SentryCrashLOG_BAK_DEBUG DEBUG
    #undef DEBUG
#endif
#ifdef TRACE
    #define SentryCrashLOG_BAK_TRACE TRACE
    #undef TRACE
#endif


#define SentryCrashLogger_Level_None   0
#define SentryCrashLogger_Level_Error 10
#define SentryCrashLogger_Level_Warn  20
#define SentryCrashLogger_Level_Info  30
#define SentryCrashLogger_Level_Debug 40
#define SentryCrashLogger_Level_Trace 50

#define SentryCrash_NONE  SentryCrashLogger_Level_None
#define ERROR SentryCrashLogger_Level_Error
#define WARN  SentryCrashLogger_Level_Warn
#define INFO  SentryCrashLogger_Level_Info
#define DEBUG SentryCrashLogger_Level_Debug
#define TRACE SentryCrashLogger_Level_Trace


#ifndef SentryCrashLogger_Level
    #define SentryCrashLogger_Level SentryCrashLogger_Level_Error
#endif

#ifndef SentryCrashLogger_LocalLevel
    #define SentryCrashLogger_LocalLevel SentryCrashLogger_Level_None
#endif

#define a_SentryCrashLOG_FULL(LEVEL, FMT, ...) \
    i_SentryCrashLOG_FULL(LEVEL, \
                 __FILE__, \
                 __LINE__, \
                 __PRETTY_FUNCTION__, \
                 FMT, \
                 ##__VA_ARGS__)



// ============================================================================
#pragma mark - API -
// ============================================================================

/** Set the filename to log to.
 *
 * @param filename The file to write to (NULL = write to stdout).
 *
 * @param overwrite If true, overwrite the log file.
 */
bool sentrycrashlog_setLogFilename(const char* filename, bool overwrite);

/** Clear the log file. */
bool sentrycrashlog_clearLogFile(void);

/** Tests if the logger would print at the specified level.
 *
 * @param LEVEL The level to test for. One of:
 *            SentryCrashLogger_Level_Error,
 *            SentryCrashLogger_Level_Warn,
 *            SentryCrashLogger_Level_Info,
 *            SentryCrashLogger_Level_Debug,
 *            SentryCrashLogger_Level_Trace,
 *
 * @return TRUE if the logger would print at the specified level.
 */
#define SentryCrashLOG_PRINTS_AT_LEVEL(LEVEL) \
    (SentryCrashLogger_Level >= LEVEL || SentryCrashLogger_LocalLevel >= LEVEL)

/** Log a message regardless of the log settings.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#define SentryCrashLOG_ALWAYS(FMT, ...) a_SentryCrashLOG_FULL("FORCE", FMT, ##__VA_ARGS__)
#define SentryCrashLOGBASIC_ALWAYS(FMT, ...) i_SentryCrashLOG_BASIC(FMT, ##__VA_ARGS__)


/** Log an error.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SentryCrashLOG_PRINTS_AT_LEVEL(SentryCrashLogger_Level_Error)
    #define SentryCrashLOG_ERROR(FMT, ...) a_SentryCrashLOG_FULL("ERROR", FMT, ##__VA_ARGS__)
    #define SentryCrashLOGBASIC_ERROR(FMT, ...) i_SentryCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define SentryCrashLOG_ERROR(FMT, ...)
    #define SentryCrashLOGBASIC_ERROR(FMT, ...)
#endif

/** Log a warning.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SentryCrashLOG_PRINTS_AT_LEVEL(SentryCrashLogger_Level_Warn)
    #define SentryCrashLOG_WARN(FMT, ...)  a_SentryCrashLOG_FULL("WARN ", FMT, ##__VA_ARGS__)
    #define SentryCrashLOGBASIC_WARN(FMT, ...) i_SentryCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define SentryCrashLOG_WARN(FMT, ...)
    #define SentryCrashLOGBASIC_WARN(FMT, ...)
#endif

/** Log an info message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SentryCrashLOG_PRINTS_AT_LEVEL(SentryCrashLogger_Level_Info)
    #define SentryCrashLOG_INFO(FMT, ...)  a_SentryCrashLOG_FULL("INFO ", FMT, ##__VA_ARGS__)
    #define SentryCrashLOGBASIC_INFO(FMT, ...) i_SentryCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define SentryCrashLOG_INFO(FMT, ...)
    #define SentryCrashLOGBASIC_INFO(FMT, ...)
#endif

/** Log a debug message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SentryCrashLOG_PRINTS_AT_LEVEL(SentryCrashLogger_Level_Debug)
    #define SentryCrashLOG_DEBUG(FMT, ...) a_SentryCrashLOG_FULL("DEBUG", FMT, ##__VA_ARGS__)
    #define SentryCrashLOGBASIC_DEBUG(FMT, ...) i_SentryCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define SentryCrashLOG_DEBUG(FMT, ...)
    #define SentryCrashLOGBASIC_DEBUG(FMT, ...)
#endif

/** Log a trace message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if SentryCrashLOG_PRINTS_AT_LEVEL(SentryCrashLogger_Level_Trace)
    #define SentryCrashLOG_TRACE(FMT, ...) a_SentryCrashLOG_FULL("TRACE", FMT, ##__VA_ARGS__)
    #define SentryCrashLOGBASIC_TRACE(FMT, ...) i_SentryCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define SentryCrashLOG_TRACE(FMT, ...)
    #define SentryCrashLOGBASIC_TRACE(FMT, ...)
#endif



// ============================================================================
#pragma mark - (internal) -
// ============================================================================

/* Put everything back to the way we found it. */
#undef ERROR
#ifdef SentryCrashLOG_BAK_ERROR
    #define ERROR SentryCrashLOG_BAK_ERROR
    #undef SentryCrashLOG_BAK_ERROR
#endif
#undef WARNING
#ifdef SentryCrashLOG_BAK_WARN
    #define WARNING SentryCrashLOG_BAK_WARN
    #undef SentryCrashLOG_BAK_WARN
#endif
#undef INFO
#ifdef SentryCrashLOG_BAK_INFO
    #define INFO SentryCrashLOG_BAK_INFO
    #undef SentryCrashLOG_BAK_INFO
#endif
#undef DEBUG
#ifdef SentryCrashLOG_BAK_DEBUG
    #define DEBUG SentryCrashLOG_BAK_DEBUG
    #undef SentryCrashLOG_BAK_DEBUG
#endif
#undef TRACE
#ifdef SentryCrashLOG_BAK_TRACE
    #define TRACE SentryCrashLOG_BAK_TRACE
    #undef SentryCrashLOG_BAK_TRACE
#endif


#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashLogger_h
