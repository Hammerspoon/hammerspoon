// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashReport.m
//
//  Created by Karl Stenerud on 2012-01-28.
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

#include "SentryCrashReport.h"

#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashCPU.h"
#include "SentryCrashCachedData.h"
#include "SentryCrashDynamicLinker.h"
#include "SentryCrashFileUtils.h"
#include "SentryCrashJSONCodec.h"
#include "SentryCrashMach.h"
#include "SentryCrashMemory.h"
#include "SentryCrashObjC.h"
#include "SentryCrashReportFields.h"
#include "SentryCrashReportVersion.h"
#include "SentryCrashReportWriter.h"
#include "SentryCrashSignalInfo.h"
#include "SentryCrashStackCursor_Backtrace.h"
#include "SentryCrashStackCursor_MachineContext.h"
#include "SentryCrashString.h"
#include "SentryCrashThread.h"
#include "SentryCrashUUIDConversion.h"
#include "SentryInternalCDefines.h"
#include "SentryScopeSyncC.h"

#include "SentryAsyncSafeLog.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// ============================================================================
#pragma mark - Constants -
// ============================================================================

/** Default number of objects, subobjects, and ivars to record from a memory loc
 */
#define kDefaultMemorySearchDepth 15

/** How far to search the stack (in pointer sized jumps) for notable data. */
#define kStackNotableSearchBackDistance 20
#define kStackNotableSearchForwardDistance 10

/** How much of the stack to dump (in pointer sized jumps). */
#define kStackContentsPushedDistance 20
#define kStackContentsPoppedDistance 10
#define kStackContentsTotalDistance (kStackContentsPushedDistance + kStackContentsPoppedDistance)

/** The minimum length for a valid string. */
#define kMinStringLength 4

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

#define getJsonContext(REPORT_WRITER) ((SentryCrashJSONEncodeContext *)((REPORT_WRITER)->context))

// ============================================================================
#pragma mark - Runtime Config -
// ============================================================================

typedef struct {
    /** If YES, introspect memory contents during a crash.
     * Any Objective-C objects or C strings near the stack pointer or referenced
     * by cpu registers or exceptions will be recorded in the crash report,
     * along with their contents.
     */
    bool enabled;

    /** List of classes that should never be introspected.
     * Whenever a class in this list is encountered, only the class name will be
     * recorded.
     */
    const char **restrictedClasses;
    int restrictedClassesCount;
} SentryCrash_IntrospectionRules;

static const char *g_userInfoJSON;
static SentryCrash_IntrospectionRules g_introspectionRules;

#pragma mark Callbacks

static void
addBooleanElement(
    const SentryCrashReportWriter *const writer, const char *const key, const bool value)
{
    sentrycrashjson_addBooleanElement(getJsonContext(writer), key, value);
}

static void
addFloatingPointElement(
    const SentryCrashReportWriter *const writer, const char *const key, const double value)
{
    sentrycrashjson_addFloatingPointElement(getJsonContext(writer), key, value);
}

static void
addIntegerElement(
    const SentryCrashReportWriter *const writer, const char *const key, const int64_t value)
{
    sentrycrashjson_addIntegerElement(getJsonContext(writer), key, value);
}

static void
addUIntegerElement(
    const SentryCrashReportWriter *const writer, const char *const key, const uint64_t value)
{
    sentrycrashjson_addUIntegerElement(getJsonContext(writer), key, value);
}

static void
addStringElement(
    const SentryCrashReportWriter *const writer, const char *const key, const char *const value)
{
    sentrycrashjson_addStringElement(
        getJsonContext(writer), key, value, SentryCrashJSON_SIZE_AUTOMATIC);
}

static void
addTextFileElement(
    const SentryCrashReportWriter *const writer, const char *const key, const char *const filePath)
{
    const int fd = open(filePath, O_RDONLY);
    if (fd < 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Could not open file %s: %s", filePath, strerror(errno));
        return;
    }

    if (sentrycrashjson_beginStringElement(getJsonContext(writer), key) != SentryCrashJSON_OK) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Could not start string element");
        goto done;
    }

    char buffer[512];
    int bytesRead;
    for (bytesRead = (int)read(fd, buffer, sizeof(buffer)); bytesRead > 0;
         bytesRead = (int)read(fd, buffer, sizeof(buffer))) {
        if (sentrycrashjson_appendStringElement(getJsonContext(writer), buffer, bytesRead)
            != SentryCrashJSON_OK) {
            SENTRY_ASYNC_SAFE_LOG_ERROR("Could not append string element");
            goto done;
        }
    }

done:
    sentrycrashjson_endStringElement(getJsonContext(writer));
    close(fd);
}

static void
addDataElement(const SentryCrashReportWriter *const writer, const char *const key,
    const char *const value, const int length)
{
    sentrycrashjson_addDataElement(getJsonContext(writer), key, value, length);
}

static void
beginDataElement(const SentryCrashReportWriter *const writer, const char *const key)
{
    sentrycrashjson_beginDataElement(getJsonContext(writer), key);
}

static void
appendDataElement(
    const SentryCrashReportWriter *const writer, const char *const value, const int length)
{
    sentrycrashjson_appendDataElement(getJsonContext(writer), value, length);
}

static void
endDataElement(const SentryCrashReportWriter *const writer)
{
    sentrycrashjson_endDataElement(getJsonContext(writer));
}

static void
addUUIDElement(const SentryCrashReportWriter *const writer, const char *const key,
    const unsigned char *const value)
{
    if (value == NULL) {
        sentrycrashjson_addNullElement(getJsonContext(writer), key);
    } else {
        int uuidLength = 36;
        char uuidBuffer[uuidLength + 1]; // one for the null terminator
        const unsigned char *src = value;
        char *dst = uuidBuffer;

        sentrycrashdl_convertBinaryImageUUID(src, dst);

        sentrycrashjson_addStringElement(getJsonContext(writer), key, uuidBuffer, uuidLength);
    }
}

static void
addJSONElement(const SentryCrashReportWriter *const writer, const char *const key,
    const char *const jsonElement, bool closeLastContainer)
{
    int jsonResult = sentrycrashjson_addJSONElement(
        getJsonContext(writer), key, jsonElement, (int)strlen(jsonElement), closeLastContainer);
    if (jsonResult != SentryCrashJSON_OK) {
        char errorBuff[100];
        snprintf(errorBuff, sizeof(errorBuff), "Invalid JSON data: %s",
            sentrycrashjson_stringForError(jsonResult));
        sentrycrashjson_beginObject(getJsonContext(writer), key);
        sentrycrashjson_addStringElement(getJsonContext(writer), SentryCrashField_Error, errorBuff,
            SentryCrashJSON_SIZE_AUTOMATIC);
        sentrycrashjson_addStringElement(getJsonContext(writer), SentryCrashField_JSONData,
            jsonElement, SentryCrashJSON_SIZE_AUTOMATIC);
        sentrycrashjson_endContainer(getJsonContext(writer));
    }
}

static void
addJSONElementFromFile(const SentryCrashReportWriter *const writer, const char *const key,
    const char *const filePath, bool closeLastContainer)
{
    sentrycrashjson_addJSONFromFile(getJsonContext(writer), key, filePath, closeLastContainer);
}

static void
beginObject(const SentryCrashReportWriter *const writer, const char *const key)
{
    sentrycrashjson_beginObject(getJsonContext(writer), key);
}

static void
beginArray(const SentryCrashReportWriter *const writer, const char *const key)
{
    sentrycrashjson_beginArray(getJsonContext(writer), key);
}

static void
endContainer(const SentryCrashReportWriter *const writer)
{
    sentrycrashjson_endContainer(getJsonContext(writer));
}

static void
addTextLinesFromFile(
    const SentryCrashReportWriter *const writer, const char *const key, const char *const filePath)
{
    char readBuffer[1024];
    SentryCrashBufferedReader reader;
    if (!sentrycrashfu_openBufferedReader(&reader, filePath, readBuffer, sizeof(readBuffer))) {
        return;
    }
    char buffer[1024];
    beginArray(writer, key);
    {
        for (;;) {
            int length = sizeof(buffer);
            sentrycrashfu_readBufferedReaderUntilChar(&reader, '\n', buffer, &length);
            if (length <= 0) {
                break;
            }
            buffer[length - 1] = '\0';
            sentrycrashjson_addStringElement(
                getJsonContext(writer), NULL, buffer, SentryCrashJSON_SIZE_AUTOMATIC);
        }
    }
    endContainer(writer);
    sentrycrashfu_closeBufferedReader(&reader);
}

static int
addJSONData(const char *restrict const data, const int length, void *restrict userData)
{
    SentryCrashBufferedWriter *writer = (SentryCrashBufferedWriter *)userData;
    const bool success = sentrycrashfu_writeBufferedWriter(writer, data, length);
    return success ? SentryCrashJSON_OK : SentryCrashJSON_ERROR_CANNOT_ADD_DATA;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Check if a memory address points to a valid null terminated UTF-8 string.
 *
 * @param address The address to check.
 *
 * @return true if the address points to a string.
 */
static bool
isValidString(const void *const address)
{
    if ((void *)address == NULL) {
        return false;
    }

    char buffer[500];
    if ((uintptr_t)address + sizeof(buffer) < (uintptr_t)address) {
        // Wrapped around the address range.
        return false;
    }
    if (!sentrycrashmem_copySafely(address, buffer, sizeof(buffer))) {
        return false;
    }
    return sentrycrashstring_isNullTerminatedUTF8String(buffer, kMinStringLength, sizeof(buffer));
}

/** Get the backtrace for the specified machine context.
 *
 * This function will choose how to fetch the backtrace based on the crash and
 * machine context. It may store the backtrace in backtraceBuffer unless it can
 * be fetched directly from memory. Do not count on backtraceBuffer containing
 * anything. Always use the return value.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The machine context.
 *
 * @param cursor The stack cursor to fill.
 *
 * @return True if the cursor was filled.
 */
static bool
getStackCursor(const SentryCrash_MonitorContext *const crash,
    const struct SentryCrashMachineContext *const machineContext, SentryCrashStackCursor *cursor)
{
    if (sentrycrashmc_getThreadFromContext(machineContext)
        == sentrycrashmc_getThreadFromContext(crash->offendingMachineContext)) {
        *cursor = *((SentryCrashStackCursor *)crash->stackCursor);
        return true;
    }

    sentrycrashsc_initWithMachineContext(
        cursor, SentryCrashSC_STACK_OVERFLOW_THRESHOLD, machineContext);
    return true;
}

// ============================================================================
#pragma mark - Report Writing -
// ============================================================================

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeMemoryContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t address, int *limit);

/** Write a string to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void
writeNSStringContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    char buffer[200];
    if (sentrycrashobjc_copyStringContents(object, buffer, sizeof(buffer))) {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a URL to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void
writeURLContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    char buffer[200];
    if (sentrycrashobjc_copyStringContents(object, buffer, sizeof(buffer))) {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a date to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void
writeDateContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    writer->addFloatingPointElement(writer, key, sentrycrashobjc_dateContents(object));
}

/** Write a number to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void
writeNumberContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    writer->addFloatingPointElement(writer, key, sentrycrashobjc_numberAsFloat(object));
}

/** Write an array to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void
writeArrayContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t objectAddress, int *limit)
{
    const void *object = (const void *)objectAddress;
    uintptr_t firstObject;
    if (sentrycrashobjc_arrayContents(object, &firstObject, 1) == 1) {
        writeMemoryContents(writer, key, firstObject, limit);
    }
}

/** Write out ivar information about an unknown object.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void
writeUnknownObjectContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t objectAddress, int *limit)
{
    (*limit)--;
    const void *object = (const void *)objectAddress;
    SentryCrashObjCIvar ivars[10];
    int8_t s8;
    int16_t s16;
    int sInt;
    int32_t s32;
    int64_t s64;
    uint8_t u8;
    uint16_t u16;
    unsigned int uInt;
    uint32_t u32;
    uint64_t u64;
    float f32;
    double f64;
    bool b;
    void *pointer;

    writer->beginObject(writer, key);
    {
        if (sentrycrashobjc_isTaggedPointer(object)) {
            writer->addIntegerElement(
                writer, "tagged_payload", (int64_t)sentrycrashobjc_taggedPointerPayload(object));
        } else {
            const void *class = sentrycrashobjc_isaPointer(object);
            int ivarCount = sentrycrashobjc_ivarList(class, ivars, sizeof(ivars) / sizeof(*ivars));
            *limit -= ivarCount;
            for (int i = 0; i < ivarCount; i++) {
                SentryCrashObjCIvar *ivar = &ivars[i];
                switch (ivar->type[0]) {
                case 'c':
                    sentrycrashobjc_ivarValue(object, ivar->index, &s8);
                    writer->addIntegerElement(writer, ivar->name, s8);
                    break;
                case 'i':
                    sentrycrashobjc_ivarValue(object, ivar->index, &sInt);
                    writer->addIntegerElement(writer, ivar->name, sInt);
                    break;
                case 's':
                    sentrycrashobjc_ivarValue(object, ivar->index, &s16);
                    writer->addIntegerElement(writer, ivar->name, s16);
                    break;
                case 'l':
                    sentrycrashobjc_ivarValue(object, ivar->index, &s32);
                    writer->addIntegerElement(writer, ivar->name, s32);
                    break;
                case 'q':
                    sentrycrashobjc_ivarValue(object, ivar->index, &s64);
                    writer->addIntegerElement(writer, ivar->name, s64);
                    break;
                case 'C':
                    sentrycrashobjc_ivarValue(object, ivar->index, &u8);
                    writer->addUIntegerElement(writer, ivar->name, u8);
                    break;
                case 'I':
                    sentrycrashobjc_ivarValue(object, ivar->index, &uInt);
                    writer->addUIntegerElement(writer, ivar->name, uInt);
                    break;
                case 'S':
                    sentrycrashobjc_ivarValue(object, ivar->index, &u16);
                    writer->addUIntegerElement(writer, ivar->name, u16);
                    break;
                case 'L':
                    sentrycrashobjc_ivarValue(object, ivar->index, &u32);
                    writer->addUIntegerElement(writer, ivar->name, u32);
                    break;
                case 'Q':
                    sentrycrashobjc_ivarValue(object, ivar->index, &u64);
                    writer->addUIntegerElement(writer, ivar->name, u64);
                    break;
                case 'f':
                    sentrycrashobjc_ivarValue(object, ivar->index, &f32);
                    writer->addFloatingPointElement(writer, ivar->name, f32);
                    break;
                case 'd':
                    sentrycrashobjc_ivarValue(object, ivar->index, &f64);
                    writer->addFloatingPointElement(writer, ivar->name, f64);
                    break;
                case 'B':
                    sentrycrashobjc_ivarValue(object, ivar->index, &b);
                    writer->addBooleanElement(writer, ivar->name, b);
                    break;
                case '*':
                case '@':
                case '#':
                case ':':
                    sentrycrashobjc_ivarValue(object, ivar->index, &pointer);
                    writeMemoryContents(writer, ivar->name, (uintptr_t)pointer, limit);
                    break;
                default:
                    SENTRY_ASYNC_SAFE_LOG_DEBUG(
                        "%s: Unknown ivar type [%s]", ivar->name, ivar->type);
                }
            }
        }
    }
    writer->endContainer(writer);
}

static bool
isRestrictedClass(const char *name)
{
    if (g_introspectionRules.restrictedClasses != NULL) {
        for (int i = 0; i < g_introspectionRules.restrictedClassesCount; i++) {
            const char *className = g_introspectionRules.restrictedClasses[i];
            if (className != NULL && strcmp(name, className) == 0) {
                return true;
            }
        }
    }
    return false;
}

static bool
writeObjCObject(const SentryCrashReportWriter *const writer, const uintptr_t address, int *limit)
{
    const void *object = (const void *)address;
    switch (sentrycrashobjc_objectType(object)) {
    case SentryCrashObjCTypeClass:
        writer->addStringElement(writer, SentryCrashField_Type, SentryCrashMemType_Class);
        writer->addStringElement(writer, SentryCrashField_Class, sentrycrashobjc_className(object));
        return true;
    case SentryCrashObjCTypeObject: {
        writer->addStringElement(writer, SentryCrashField_Type, SentryCrashMemType_Object);
        const char *className = sentrycrashobjc_objectClassName(object);
        writer->addStringElement(writer, SentryCrashField_Class, className);
        if (!isRestrictedClass(className)) {
            switch (sentrycrashobjc_objectClassType(object)) {
            case SentryCrashObjCClassTypeString:
                writeNSStringContents(writer, SentryCrashField_Value, address, limit);
                return true;
            case SentryCrashObjCClassTypeURL:
                writeURLContents(writer, SentryCrashField_Value, address, limit);
                return true;
            case SentryCrashObjCClassTypeDate:
                writeDateContents(writer, SentryCrashField_Value, address, limit);
                return true;
            case SentryCrashObjCClassTypeArray:
                if (*limit > 0) {
                    writeArrayContents(writer, SentryCrashField_FirstObject, address, limit);
                }
                return true;
            case SentryCrashObjCClassTypeNumber:
                writeNumberContents(writer, SentryCrashField_Value, address, limit);
                return true;
            case SentryCrashObjCClassTypeDictionary:
            case SentryCrashObjCClassTypeException:
                // TODO: Implement these.
                if (*limit > 0) {
                    writeUnknownObjectContents(writer, SentryCrashField_Ivars, address, limit);
                }
                return true;
            case SentryCrashObjCClassTypeUnknown:
                if (*limit > 0) {
                    writeUnknownObjectContents(writer, SentryCrashField_Ivars, address, limit);
                }
                return true;
            }
        }
        break;
    }
    case SentryCrashObjCTypeBlock:
        writer->addStringElement(writer, SentryCrashField_Type, SentryCrashMemType_Block);
        const char *className = sentrycrashobjc_objectClassName(object);
        writer->addStringElement(writer, SentryCrashField_Class, className);
        return true;
    case SentryCrashObjCTypeUnknown:
        break;
    }

    return false;
}

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void
writeMemoryContents(const SentryCrashReportWriter *const writer, const char *const key,
    const uintptr_t address, int *limit)
{
    (*limit)--;
    const void *object = (const void *)address;
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, SentryCrashField_Address, address);
        if (!writeObjCObject(writer, address, limit)) {
            if (object == NULL) {
                writer->addStringElement(
                    writer, SentryCrashField_Type, SentryCrashMemType_NullPointer);
            } else if (isValidString(object)) {
                writer->addStringElement(writer, SentryCrashField_Type, SentryCrashMemType_String);
                writer->addStringElement(writer, SentryCrashField_Value, (const char *)object);
            } else {
                writer->addStringElement(writer, SentryCrashField_Type, SentryCrashMemType_Unknown);
            }
        }
    }
    writer->endContainer(writer);
}

static bool
isValidPointer(const uintptr_t address)
{
    if (address == (uintptr_t)NULL) {
        return false;
    }

    if (sentrycrashobjc_isTaggedPointer((const void *)address)) {
        if (!sentrycrashobjc_isValidTaggedPointer((const void *)address)) {
            return false;
        }
    }

    return true;
}

static bool
isNotableAddress(const uintptr_t address)
{
    if (!isValidPointer(address)) {
        return false;
    }

    const void *object = (const void *)address;

    if (sentrycrashobjc_objectType(object) != SentryCrashObjCTypeUnknown) {
        return true;
    }

    if (isValidString(object)) {
        return true;
    }

    return false;
}

/** Write the contents of a memory location only if it contains notable data.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 */
static void
writeMemoryContentsIfNotable(
    const SentryCrashReportWriter *const writer, const char *const key, const uintptr_t address)
{
    if (isNotableAddress(address)) {
        int limit = kDefaultMemorySearchDepth;
        writeMemoryContents(writer, key, address, &limit);
    }
}

/** Look for a hex value in a string and try to write whatever it references.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param string The string to search.
 */
static void
writeAddressReferencedByString(
    const SentryCrashReportWriter *const writer, const char *const key, const char *string)
{
    uint64_t address = 0;
    if (string == NULL
        || !sentrycrashstring_extractHexValue(string, (int)strlen(string), &address)) {
        return;
    }

    int limit = kDefaultMemorySearchDepth;
    writeMemoryContents(writer, key, (uintptr_t)address, &limit);
}

#pragma mark Backtrace

/** Write a backtrace to the report.
 *
 * @param writer The writer to write the backtrace to.
 *
 * @param key The object key, if needed.
 *
 * @param stackCursor The stack cursor to read from.
 */
static void
writeBacktrace(const SentryCrashReportWriter *const writer, const char *const key,
    SentryCrashStackCursor *stackCursor)
{
    writer->beginObject(writer, key);
    {
        writer->beginArray(writer, SentryCrashField_Contents);
        {
            while (stackCursor->advanceCursor(stackCursor)) {
                writer->beginObject(writer, NULL);
                {
                    if (stackCursor->symbolicate(stackCursor)) {
                        if (stackCursor->stackEntry.imageName != NULL) {
                            writer->addStringElement(writer, SentryCrashField_ObjectName,
                                sentrycrashfu_lastPathEntry(stackCursor->stackEntry.imageName));
                        }
                        writer->addUIntegerElement(writer, SentryCrashField_ObjectAddr,
                            stackCursor->stackEntry.imageAddress);
                        if (stackCursor->stackEntry.symbolName != NULL) {
                            writer->addStringElement(writer, SentryCrashField_SymbolName,
                                stackCursor->stackEntry.symbolName);
                        }
                        writer->addUIntegerElement(writer, SentryCrashField_SymbolAddr,
                            stackCursor->stackEntry.symbolAddress);
                    }
                    writer->addUIntegerElement(
                        writer, SentryCrashField_InstructionAddr, stackCursor->stackEntry.address);
                }
                writer->endContainer(writer);
            }
        }
        writer->endContainer(writer);
        writer->addIntegerElement(writer, SentryCrashField_Skipped, 0);
    }
    writer->endContainer(writer);
}

#pragma mark Stack

/** Write a dump of the stack contents to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param isStackOverflow If true, the stack has overflowed.
 */
static void
writeStackContents(const SentryCrashReportWriter *const writer, const char *const key,
    const struct SentryCrashMachineContext *const machineContext, const bool isStackOverflow)
{
    uintptr_t sp = sentrycrashcpu_stackPointer(machineContext);
    if ((void *)sp == NULL) {
        return;
    }

    uintptr_t lowAddress = sp
        + (uintptr_t)(kStackContentsPushedDistance * (int)sizeof(sp)
            * sentrycrashcpu_stackGrowDirection() * -1);
    uintptr_t highAddress = sp
        + (uintptr_t)(kStackContentsPoppedDistance * (int)sizeof(sp)
            * sentrycrashcpu_stackGrowDirection());
    if (highAddress < lowAddress) {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, SentryCrashField_GrowDirection,
            sentrycrashcpu_stackGrowDirection() > 0 ? "+" : "-");
        writer->addUIntegerElement(writer, SentryCrashField_DumpStart, lowAddress);
        writer->addUIntegerElement(writer, SentryCrashField_DumpEnd, highAddress);
        writer->addUIntegerElement(writer, SentryCrashField_StackPtr, sp);
        writer->addBooleanElement(writer, SentryCrashField_Overflow, isStackOverflow);
        uint8_t stackBuffer[kStackContentsTotalDistance * sizeof(sp)];
        int copyLength = (int)(highAddress - lowAddress);
        if (sentrycrashmem_copySafely((void *)lowAddress, stackBuffer, copyLength)) {
            writer->addDataElement(
                writer, SentryCrashField_Contents, (void *)stackBuffer, copyLength);
        } else {
            writer->addStringElement(
                writer, SentryCrashField_Error, "Stack contents not accessible");
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses near the stack pointer (above and below).
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param backDistance The distance towards the beginning of the stack to check.
 *
 * @param forwardDistance The distance past the end of the stack to check.
 */
static void
writeNotableStackContents(const SentryCrashReportWriter *const writer,
    const struct SentryCrashMachineContext *const machineContext, const int backDistance,
    const int forwardDistance)
{
    uintptr_t sp = sentrycrashcpu_stackPointer(machineContext);
    if ((void *)sp == NULL) {
        return;
    }

    uintptr_t lowAddress = sp
        + (uintptr_t)(backDistance * (int)sizeof(sp) * sentrycrashcpu_stackGrowDirection() * -1);
    uintptr_t highAddress
        = sp + (uintptr_t)(forwardDistance * (int)sizeof(sp) * sentrycrashcpu_stackGrowDirection());
    if (highAddress < lowAddress) {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    uintptr_t contentsAsPointer;
    char nameBuffer[40];
    for (uintptr_t address = lowAddress; address < highAddress; address += sizeof(address)) {
        if (sentrycrashmem_copySafely(
                (void *)address, &contentsAsPointer, sizeof(contentsAsPointer))) {
            snprintf(nameBuffer, sizeof(nameBuffer), "stack@%p", (void *)address);
            writeMemoryContentsIfNotable(writer, nameBuffer, contentsAsPointer);
        }
    }
}

#pragma mark Registers

/** Write the contents of all regular registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void
writeBasicRegisters(const SentryCrashReportWriter *const writer, const char *const key,
    const struct SentryCrashMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = sentrycrashcpu_numRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = sentrycrashcpu_registerName(reg);
            if (registerName == NULL) {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(
                writer, registerName, sentrycrashcpu_registerValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write the contents of all exception registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void
writeExceptionRegisters(const SentryCrashReportWriter *const writer, const char *const key,
    const struct SentryCrashMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = sentrycrashcpu_numExceptionRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = sentrycrashcpu_exceptionRegisterName(reg);
            if (registerName == NULL) {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(
                writer, registerName, sentrycrashcpu_exceptionRegisterValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write all applicable registers.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void
writeRegisters(const SentryCrashReportWriter *const writer, const char *const key,
    const struct SentryCrashMachineContext *const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeBasicRegisters(writer, SentryCrashField_Basic, machineContext);
        if (sentrycrashmc_hasValidExceptionRegisters(machineContext)) {
            writeExceptionRegisters(writer, SentryCrashField_Exception, machineContext);
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses contained in the CPU registers.
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void
writeNotableRegisters(const SentryCrashReportWriter *const writer,
    const struct SentryCrashMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    const int numRegisters = sentrycrashcpu_numRegisters();
    for (int reg = 0; reg < numRegisters; reg++) {
        registerName = sentrycrashcpu_registerName(reg);
        if (registerName == NULL) {
            snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
            registerName = registerNameBuff;
        }
        writeMemoryContentsIfNotable(
            writer, registerName, (uintptr_t)sentrycrashcpu_registerValue(machineContext, reg));
    }
}

#pragma mark Thread-specific

/** Write any notable addresses in the stack or registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void
writeNotableAddresses(const SentryCrashReportWriter *const writer, const char *const key,
    const struct SentryCrashMachineContext *const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeNotableRegisters(writer, machineContext);
        writeNotableStackContents(writer, machineContext, kStackNotableSearchBackDistance,
            kStackNotableSearchForwardDistance);
    }
    writer->endContainer(writer);
}

/** Write information about a thread to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The context whose thread to write about.
 *
 * @param shouldWriteNotableAddresses If true, write any notable addresses
 * found.
 */
static void
writeThread(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const crash,
    const struct SentryCrashMachineContext *const machineContext, const int threadIndex,
    const bool shouldWriteNotableAddresses)
{
    bool isCrashedThread = sentrycrashmc_isCrashedContext(machineContext);
    SentryCrashThread thread = sentrycrashmc_getThreadFromContext(machineContext);
    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "Writing thread %x (index %d). is crashed: %d", thread, threadIndex, isCrashedThread);

    SentryCrashStackCursor stackCursor;

    bool hasBacktrace = getStackCursor(crash, machineContext, &stackCursor);

    writer->beginObject(writer, key);
    {
        if (hasBacktrace) {
            writeBacktrace(writer, SentryCrashField_Backtrace, &stackCursor);
        }
        if (sentrycrashmc_canHaveCPUState(machineContext)) {
            writeRegisters(writer, SentryCrashField_Registers, machineContext);
        }
        writer->addIntegerElement(writer, SentryCrashField_Index, threadIndex);
        const char *name = sentrycrashccd_getThreadName(thread);
        if (name != NULL) {
            writer->addStringElement(writer, SentryCrashField_Name, name);
        }
        name = sentrycrashccd_getQueueName(thread);
        if (name != NULL) {
            writer->addStringElement(writer, SentryCrashField_DispatchQueue, name);
        }
        writer->addBooleanElement(writer, SentryCrashField_Crashed, isCrashedThread);
        writer->addBooleanElement(
            writer, SentryCrashField_CurrentThread, thread == sentrycrashthread_self());
        if (isCrashedThread) {
            writeStackContents(
                writer, SentryCrashField_Stack, machineContext, stackCursor.state.hasGivenUp);
            if (shouldWriteNotableAddresses) {
                writeNotableAddresses(writer, SentryCrashField_NotableAddresses, machineContext);
            }
        }
    }
    writer->endContainer(writer);
}

/** Write information about all threads to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void
writeAllThreads(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const crash, bool writeNotableAddresses)
{
    const struct SentryCrashMachineContext *const context = crash->offendingMachineContext;

    if (!context)
        return;

    SentryCrashThread offendingThread = sentrycrashmc_getThreadFromContext(context);
    int threadCount = sentrycrashmc_getThreadCount(context);
    SentryCrashMC_NEW_CONTEXT(machineContext);

    // Fetch info for all threads.
    writer->beginArray(writer, key);
    {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Writing %d threads.", threadCount);
        for (int i = 0; i < threadCount; i++) {
            SentryCrashThread thread = sentrycrashmc_getThreadAtIndex(context, i);
            if (thread == offendingThread) {
                writeThread(writer, NULL, crash, context, i, writeNotableAddresses);
            } else {
                sentrycrashmc_getContextForThread(thread, machineContext, false);
                writeThread(writer, NULL, crash, machineContext, i, writeNotableAddresses);
            }
        }
    }
    writer->endContainer(writer);
}

#pragma mark Global Report Data

/** Write information about a binary image to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param image Which image to write about.
 */
static void
writeBinaryImage(const SentryCrashReportWriter *const writer, const char *const key,
    SentryCrashBinaryImage *image)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, SentryCrashField_ImageAddress, image->address);
        writer->addUIntegerElement(writer, SentryCrashField_ImageVmAddress, image->vmAddress);
        writer->addUIntegerElement(writer, SentryCrashField_ImageSize, image->size);
        writer->addStringElement(writer, SentryCrashField_Name, image->name);
        writer->addUUIDElement(writer, SentryCrashField_UUID, image->uuid);
        writer->addIntegerElement(writer, SentryCrashField_CPUType, image->cpuType);
        writer->addIntegerElement(writer, SentryCrashField_CPUSubType, image->cpuSubType);
        writer->addUIntegerElement(writer, SentryCrashField_ImageMajorVersion, image->majorVersion);
        writer->addUIntegerElement(writer, SentryCrashField_ImageMinorVersion, image->minorVersion);
        writer->addUIntegerElement(
            writer, SentryCrashField_ImageRevisionVersion, image->revisionVersion);
        if (image->crashInfoMessage != NULL) {
            writer->addStringElement(
                writer, SentryCrashField_ImageCrashInfoMessage, image->crashInfoMessage);
        }
        if (image->crashInfoMessage2 != NULL) {
            writer->addStringElement(
                writer, SentryCrashField_ImageCrashInfoMessage2, image->crashInfoMessage2);
        }
    }
    writer->endContainer(writer);
}

static void
binaryImagesIteratorCallback(SentryCrashBinaryImage *image, void *context)
{
    SentryCrashReportWriter *writer = (SentryCrashReportWriter *)context;
    writeBinaryImage(writer, NULL, image);
}

/** Write information about all images to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void
writeBinaryImages(const SentryCrashReportWriter *const writer, const char *const key)
{
    writer->beginArray(writer, key);
    sentrycrashbic_iterateOverImages(&binaryImagesIteratorCallback, (void *)writer);
    writer->endContainer(writer);
}

/** Write information about system memory to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void
writeMemoryInfo(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(
            writer, SentryCrashField_Size, monitorContext->System.memorySize);
        writer->addUIntegerElement(
            writer, SentryCrashField_Usable, monitorContext->System.usableMemorySize);
        writer->addUIntegerElement(
            writer, SentryCrashField_Free, monitorContext->System.freeMemorySize);
    }
    writer->endContainer(writer);
}

/** Write information about the error leading to the crash to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void
writeError(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const crash)
{
    writer->beginObject(writer, key);
    {
#if SENTRY_HOST_APPLE
        writer->beginObject(writer, SentryCrashField_Mach);
        {
            const char *machExceptionName = sentrycrashmach_exceptionName(crash->mach.type);
            const char *machCodeName = crash->mach.code == 0
                ? NULL
                : sentrycrashmach_kernelReturnCodeName(crash->mach.code);
            writer->addUIntegerElement(
                writer, SentryCrashField_Exception, (unsigned)crash->mach.type);
            if (machExceptionName != NULL) {
                writer->addStringElement(writer, SentryCrashField_ExceptionName, machExceptionName);
            }
            writer->addUIntegerElement(writer, SentryCrashField_Code, (unsigned)crash->mach.code);
            if (machCodeName != NULL) {
                writer->addStringElement(writer, SentryCrashField_CodeName, machCodeName);
            }
            writer->addUIntegerElement(
                writer, SentryCrashField_Subcode, (size_t)crash->mach.subcode);
        }
        writer->endContainer(writer);
#endif
        writer->beginObject(writer, SentryCrashField_Signal);
        {
            const char *sigName = sentrycrashsignal_signalName(crash->signal.signum);
            const char *sigCodeName
                = sentrycrashsignal_signalCodeName(crash->signal.signum, crash->signal.sigcode);
            writer->addUIntegerElement(
                writer, SentryCrashField_Signal, (unsigned)crash->signal.signum);
            if (sigName != NULL) {
                writer->addStringElement(writer, SentryCrashField_Name, sigName);
            }
            writer->addUIntegerElement(
                writer, SentryCrashField_Code, (unsigned)crash->signal.sigcode);
            if (sigCodeName != NULL) {
                writer->addStringElement(writer, SentryCrashField_CodeName, sigCodeName);
            }
        }
        writer->endContainer(writer);

        writer->addUIntegerElement(writer, SentryCrashField_Address, crash->faultAddress);
        if (crash->crashReason != NULL) {
            writer->addStringElement(writer, SentryCrashField_Reason, crash->crashReason);
        }

        // Gather specific info.
        switch (crash->crashType) {

        case SentryCrashMonitorTypeMachException:
            writer->addStringElement(writer, SentryCrashField_Type, SentryCrashExcType_Mach);
            break;

        case SentryCrashMonitorTypeCPPException: {
            writer->addStringElement(
                writer, SentryCrashField_Type, SentryCrashExcType_CPPException);
            writer->beginObject(writer, SentryCrashField_CPPException);
            {
                writer->addStringElement(writer, SentryCrashField_Name, crash->CPPException.name);
            }
            writer->endContainer(writer);
            break;
        }
        case SentryCrashMonitorTypeNSException: {
            writer->addStringElement(writer, SentryCrashField_Type, SentryCrashExcType_NSException);
            writer->beginObject(writer, SentryCrashField_NSException);
            {
                writer->addStringElement(writer, SentryCrashField_Name, crash->NSException.name);
                writer->addStringElement(
                    writer, SentryCrashField_UserInfo, crash->NSException.userInfo);
                if (crash->crashReason != NULL) {
                    writer->addStringElement(writer, SentryCrashField_Reason, crash->crashReason);
                }
            }
            writer->endContainer(writer);
            break;
        }
        case SentryCrashMonitorTypeSignal:
            writer->addStringElement(writer, SentryCrashField_Type, SentryCrashExcType_Signal);
            break;

        case SentryCrashMonitorTypeSystem:
        case SentryCrashMonitorTypeApplicationState:
            SENTRY_ASYNC_SAFE_LOG_ERROR(
                "Crash monitor type 0x%x shouldn't be able to cause events!", crash->crashType);
            break;
        }
    }
    writer->endContainer(writer);
}

/** Write information about app runtime, etc to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param monitorContext The event monitor context.
 */
static void
writeAppStats(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addBooleanElement(
            writer, SentryCrashField_AppActive, monitorContext->AppState.applicationIsActive);
        writer->addBooleanElement(
            writer, SentryCrashField_AppInFG, monitorContext->AppState.applicationIsInForeground);

        writer->addIntegerElement(writer, SentryCrashField_LaunchesSinceCrash,
            monitorContext->AppState.launchesSinceLastCrash);
        writer->addIntegerElement(writer, SentryCrashField_SessionsSinceCrash,
            monitorContext->AppState.sessionsSinceLastCrash);
        writer->addFloatingPointElement(writer, SentryCrashField_ActiveTimeSinceCrash,
            monitorContext->AppState.activeDurationSinceLastCrash);
        writer->addFloatingPointElement(writer, SentryCrashField_BGTimeSinceCrash,
            monitorContext->AppState.backgroundDurationSinceLastCrash);

        writer->addIntegerElement(writer, SentryCrashField_SessionsSinceLaunch,
            monitorContext->AppState.sessionsSinceLaunch);
        writer->addFloatingPointElement(writer, SentryCrashField_ActiveTimeSinceLaunch,
            monitorContext->AppState.activeDurationSinceLaunch);
        writer->addFloatingPointElement(writer, SentryCrashField_BGTimeSinceLaunch,
            monitorContext->AppState.backgroundDurationSinceLaunch);
    }
    writer->endContainer(writer);
}

/** Write information about this process.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void
writeProcessState(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        if (monitorContext->ZombieException.address != 0) {
            writer->beginObject(writer, SentryCrashField_LastDeallocedNSException);
            {
                writer->addUIntegerElement(
                    writer, SentryCrashField_Address, monitorContext->ZombieException.address);
                writer->addStringElement(
                    writer, SentryCrashField_Name, monitorContext->ZombieException.name);
                writer->addStringElement(
                    writer, SentryCrashField_Reason, monitorContext->ZombieException.reason);
                writeAddressReferencedByString(writer, SentryCrashField_ReferencedObject,
                    monitorContext->ZombieException.reason);
            }
            writer->endContainer(writer);
        }
    }
    writer->endContainer(writer);
}

/** Write basic report information.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param type The report type.
 *
 * @param reportID The report ID.
 */
static void
writeReportInfo(const SentryCrashReportWriter *const writer, const char *const key,
    const char *const type, const char *const reportID, const char *const processName)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, SentryCrashField_Version, SENTRY_REPORT_VERSION);
        writer->addStringElement(writer, SentryCrashField_ID, reportID);
        writer->addStringElement(writer, SentryCrashField_ProcessName, processName);
        writer->addIntegerElement(writer, SentryCrashField_Timestamp, time(NULL));
        writer->addStringElement(writer, SentryCrashField_Type, type);
    }
    writer->endContainer(writer);
}

static void
writeRecrash(
    const SentryCrashReportWriter *const writer, const char *const key, const char *crashReportPath)
{
    writer->addJSONFileElement(writer, key, crashReportPath, true);
}

#pragma mark Setup

/** Prepare a report writer for use.
 *
 * @oaram writer The writer to prepare.
 *
 * @param context JSON writer contextual information.
 */
static void
prepareReportWriter(
    SentryCrashReportWriter *const writer, SentryCrashJSONEncodeContext *const context)
{
    writer->addBooleanElement = addBooleanElement;
    writer->addFloatingPointElement = addFloatingPointElement;
    writer->addIntegerElement = addIntegerElement;
    writer->addUIntegerElement = addUIntegerElement;
    writer->addStringElement = addStringElement;
    writer->addTextFileElement = addTextFileElement;
    writer->addTextFileLinesElement = addTextLinesFromFile;
    writer->addJSONFileElement = addJSONElementFromFile;
    writer->addDataElement = addDataElement;
    writer->beginDataElement = beginDataElement;
    writer->appendDataElement = appendDataElement;
    writer->endDataElement = endDataElement;
    writer->addUUIDElement = addUUIDElement;
    writer->addJSONElement = addJSONElement;
    writer->beginObject = beginObject;
    writer->beginArray = beginArray;
    writer->endContainer = endContainer;
    writer->context = context;
}

// ============================================================================
#pragma mark - Main API -
// ============================================================================

void
sentrycrashreport_writeRecrashReport(
    const SentryCrash_MonitorContext *const monitorContext, const char *const path)
{
    char writeBuffer[1024];
    SentryCrashBufferedWriter bufferedWriter;
    static char tempPath[SentryCrashFU_MAX_PATH_LENGTH];
    strncpy(tempPath, path, sizeof(tempPath) - 10);
    strncpy(tempPath + strlen(tempPath) - 5, ".old", 5);
    SENTRY_ASYNC_SAFE_LOG_INFO("Writing recrash report to %s", path);

    if (rename(path, tempPath) < 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Could not rename %s to %s: %s", path, tempPath, strerror(errno));
    }
    if (!sentrycrashfu_openBufferedWriter(
            &bufferedWriter, path, writeBuffer, sizeof(writeBuffer))) {
        return;
    }

    sentrycrashccd_freeze();

    SentryCrashJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    SentryCrashReportWriter concreteWriter;
    SentryCrashReportWriter *writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    sentrycrashjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, SentryCrashField_Report);
    {
        writeRecrash(writer, SentryCrashField_RecrashReport, tempPath);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);
        if (remove(tempPath) < 0) {
            SENTRY_ASYNC_SAFE_LOG_ERROR("Could not remove %s: %s", tempPath, strerror(errno));
        }
        writeReportInfo(writer, SentryCrashField_Report, SentryCrashReportType_Minimal,
            monitorContext->eventID, monitorContext->System.processName);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, SentryCrashField_Crash);
        {
            writeError(writer, SentryCrashField_Error, monitorContext);
            sentrycrashfu_flushBufferedWriter(&bufferedWriter);
            int threadIndex = sentrycrashmc_indexOfThread(monitorContext->offendingMachineContext,
                sentrycrashmc_getThreadFromContext(monitorContext->offendingMachineContext));
            writeThread(writer, SentryCrashField_CrashedThread, monitorContext,
                monitorContext->offendingMachineContext, threadIndex, false);
            sentrycrashfu_flushBufferedWriter(&bufferedWriter);
        }
        writer->endContainer(writer);
    }
    writer->endContainer(writer);

    sentrycrashjson_endEncode(getJsonContext(writer));
    sentrycrashfu_closeBufferedWriter(&bufferedWriter);
    sentrycrashccd_unfreeze();
}

static void
writeSystemInfo(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(
            writer, SentryCrashField_SystemName, monitorContext->System.systemName);
        writer->addStringElement(
            writer, SentryCrashField_SystemVersion, monitorContext->System.systemVersion);
        writer->addStringElement(writer, SentryCrashField_Machine, monitorContext->System.machine);
        writer->addStringElement(writer, SentryCrashField_Model, monitorContext->System.model);
        writer->addStringElement(
            writer, SentryCrashField_KernelVersion, monitorContext->System.kernelVersion);
        writer->addStringElement(
            writer, SentryCrashField_OSVersion, monitorContext->System.osVersion);
        writer->addBooleanElement(
            writer, SentryCrashField_Jailbroken, monitorContext->System.isJailbroken);
        writer->addStringElement(
            writer, SentryCrashField_AppStartTime, monitorContext->System.appStartTime);
        writer->addStringElement(
            writer, SentryCrashField_ExecutablePath, monitorContext->System.executablePath);
        writer->addStringElement(
            writer, SentryCrashField_Executable, monitorContext->System.executableName);
        writer->addStringElement(
            writer, SentryCrashField_BundleID, monitorContext->System.bundleID);
        writer->addStringElement(
            writer, SentryCrashField_BundleName, monitorContext->System.bundleName);
        writer->addStringElement(
            writer, SentryCrashField_BundleVersion, monitorContext->System.bundleVersion);
        writer->addStringElement(
            writer, SentryCrashField_BundleShortVersion, monitorContext->System.bundleShortVersion);
        writer->addStringElement(writer, SentryCrashField_AppUUID, monitorContext->System.appID);
        writer->addStringElement(
            writer, SentryCrashField_CPUArch, monitorContext->System.cpuArchitecture);
        writer->addIntegerElement(writer, SentryCrashField_CPUType, monitorContext->System.cpuType);
        writer->addIntegerElement(
            writer, SentryCrashField_CPUSubType, monitorContext->System.cpuSubType);
        writer->addIntegerElement(
            writer, SentryCrashField_BinaryCPUType, monitorContext->System.binaryCPUType);
        writer->addIntegerElement(
            writer, SentryCrashField_BinaryCPUSubType, monitorContext->System.binaryCPUSubType);
        writer->addStringElement(
            writer, SentryCrashField_ProcessName, monitorContext->System.processName);
        writer->addIntegerElement(
            writer, SentryCrashField_ProcessID, monitorContext->System.processID);
        writer->addIntegerElement(
            writer, SentryCrashField_ParentProcessID, monitorContext->System.parentProcessID);
        writer->addStringElement(
            writer, SentryCrashField_DeviceAppHash, monitorContext->System.deviceAppHash);
        writer->addStringElement(
            writer, SentryCrashField_BuildType, monitorContext->System.buildType);

        writeMemoryInfo(writer, SentryCrashField_Memory, monitorContext);
        writeAppStats(writer, SentryCrashField_AppStats, monitorContext);
    }
    writer->endContainer(writer);
}

static void
writeDebugInfo(const SentryCrashReportWriter *const writer, const char *const key,
    const SentryCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        addTextLinesFromFile(writer, SentryCrashField_ConsoleLog, g_logFilename);
    }
    writer->endContainer(writer);
}

static void
writeScopeJson(const SentryCrashReportWriter *const writer)
{
    SentryCrashScope *scope = sentrycrash_scopesync_getScope();
    writer->beginObject(writer, SentryCrashField_Scope);
    {
        if (scope->user) {
            addJSONElement(writer, "user", scope->user, false);
        }
        if (scope->dist) {
            addJSONElement(writer, "dist", scope->dist, false);
        }
        if (scope->context) {
            addJSONElement(writer, "context", scope->context, false);
        }
        if (scope->environment) {
            addJSONElement(writer, "environment", scope->environment, false);
        }
        if (scope->tags) {
            addJSONElement(writer, "tags", scope->tags, false);
        }
        if (scope->extras) {
            addJSONElement(writer, "extra", scope->extras, false);
        }
        if (scope->fingerprint) {
            addJSONElement(writer, "fingerprint", scope->fingerprint, false);
        }
        if (scope->level) {
            addJSONElement(writer, "level", scope->level, false);
        }

        if (scope->breadcrumbs) {

            bool areThereBreadcrumbs = false;
            for (int i = 0; i < scope->maxCrumbs; i++) {
                if (scope->breadcrumbs[i]) {
                    areThereBreadcrumbs = true;
                    break;
                }
            }

            if (areThereBreadcrumbs) {
                writer->beginArray(writer, "breadcrumbs");
                {
                    for (int i = 0; i < scope->maxCrumbs; i++) {
                        // Crumbs use a ringbuffer. We need to start at the current crumb to get the
                        // crumbs in the correct order.
                        long index = (scope->currentCrumb + i) % scope->maxCrumbs;
                        if (scope->breadcrumbs[index]) {
                            addJSONElement(writer, "crumb", scope->breadcrumbs[index], false);
                        }
                    }
                }
                writer->endContainer(writer);
            }
        }
    }
    writer->endContainer(writer);
}

void
sentrycrashreport_writeStandardReport(
    const SentryCrash_MonitorContext *const monitorContext, const char *const path)
{
    SENTRY_ASYNC_SAFE_LOG_INFO("Writing crash report to %s", path);
    char writeBuffer[1024];
    SentryCrashBufferedWriter bufferedWriter;

    if (!sentrycrashfu_openBufferedWriter(
            &bufferedWriter, path, writeBuffer, sizeof(writeBuffer))) {
        return;
    }

    sentrycrashccd_freeze();

    SentryCrashJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    SentryCrashReportWriter concreteWriter;
    SentryCrashReportWriter *writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    sentrycrashjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, SentryCrashField_Report);
    {
        writeReportInfo(writer, SentryCrashField_Report, SentryCrashReportType_Standard,
            monitorContext->eventID, monitorContext->System.processName);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);

        writeBinaryImages(writer, SentryCrashField_BinaryImages);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);

        writeProcessState(writer, SentryCrashField_ProcessState, monitorContext);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);

        writeSystemInfo(writer, SentryCrashField_System, monitorContext);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, SentryCrashField_Crash);
        {
            writeError(writer, SentryCrashField_Error, monitorContext);
            sentrycrashfu_flushBufferedWriter(&bufferedWriter);
            writeAllThreads(
                writer, SentryCrashField_Threads, monitorContext, g_introspectionRules.enabled);
            sentrycrashfu_flushBufferedWriter(&bufferedWriter);
        }
        writer->endContainer(writer);

        writeScopeJson(writer);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);

        if (g_userInfoJSON != NULL) {
            addJSONElement(writer, SentryCrashField_User, g_userInfoJSON, false);
            sentrycrashfu_flushBufferedWriter(&bufferedWriter);
        } else {
            writer->beginObject(writer, SentryCrashField_User);
        }
        writer->endContainer(writer);
        sentrycrashfu_flushBufferedWriter(&bufferedWriter);

        writeDebugInfo(writer, SentryCrashField_Debug, monitorContext);
    }
    writer->endContainer(writer);

    sentrycrashjson_endEncode(getJsonContext(writer));
    sentrycrashfu_closeBufferedWriter(&bufferedWriter);
    sentrycrashccd_unfreeze();
}

void
sentrycrashreport_setUserInfoJSON(const char *const userInfoJSON)
{
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    SENTRY_ASYNC_SAFE_LOG_TRACE("set userInfoJSON to %p", userInfoJSON);

    pthread_mutex_lock(&mutex);
    if (g_userInfoJSON != NULL) {
        free((void *)g_userInfoJSON);
    }
    if (userInfoJSON == NULL) {
        g_userInfoJSON = NULL;
    } else {
        g_userInfoJSON = strdup(userInfoJSON);
    }
    pthread_mutex_unlock(&mutex);
}

void
sentrycrashreport_setIntrospectMemory(bool shouldIntrospectMemory)
{
    g_introspectionRules.enabled = shouldIntrospectMemory;
}

void
sentrycrashreport_setDoNotIntrospectClasses(const char **doNotIntrospectClasses, int length)
{
    const char **oldClasses = g_introspectionRules.restrictedClasses;
    int oldClassesLength = g_introspectionRules.restrictedClassesCount;
    const char **newClasses = NULL;
    int newClassesLength = 0;

    if (doNotIntrospectClasses != NULL && length > 0) {
        newClassesLength = length;
        newClasses = malloc(sizeof(*newClasses) * (unsigned)newClassesLength);
        if (newClasses == NULL) {
            SENTRY_ASYNC_SAFE_LOG_ERROR("Could not allocate memory");
            return;
        }

        for (int i = 0; i < newClassesLength; i++) {
            newClasses[i] = strdup(doNotIntrospectClasses[i]);
        }
    }

    g_introspectionRules.restrictedClasses = newClasses;
    g_introspectionRules.restrictedClassesCount = newClassesLength;

    if (oldClasses != NULL) {
        for (int i = 0; i < oldClassesLength; i++) {
            if (oldClasses[i] != NULL) {
                free((void *)oldClasses[i]);
            }
        }
        free(oldClasses);
    }
}
