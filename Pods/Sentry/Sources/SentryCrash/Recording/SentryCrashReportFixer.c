// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashReportFixer.c
//
//  Created by Karl Stenerud on 2016-11-07.
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

#include "SentryCrashDate.h"
#include "SentryCrashJSONCodec.h"
#include "SentryCrashLogger.h"
#include "SentryCrashReportFields.h"
#include "SentryCrashSystemCapabilities.h"

#include <stdlib.h>
#include <string.h>

#define MAX_DEPTH 100
#define MAX_NAME_LENGTH 100

static char *datePaths[][MAX_DEPTH] = {
    { "", SentryCrashField_Report, SentryCrashField_Timestamp },
    { "", SentryCrashField_RecrashReport, SentryCrashField_Report, SentryCrashField_Timestamp },
};
static int datePathsCount = sizeof(datePaths) / sizeof(*datePaths);

typedef struct {
    SentryCrashJSONEncodeContext *encodeContext;
    char objectPath[MAX_DEPTH][MAX_NAME_LENGTH];
    int currentDepth;
    char *outputPtr;
    int outputBytesLeft;
} FixupContext;

static bool
increaseDepth(FixupContext *context, const char *name)
{
    if (context->currentDepth >= MAX_DEPTH) {
        return false;
    }
    if (name == NULL) {
        *context->objectPath[context->currentDepth] = '\0';
    } else {
        strncpy(context->objectPath[context->currentDepth], name,
            sizeof(context->objectPath[context->currentDepth]));
    }
    context->currentDepth++;
    return true;
}

static bool
decreaseDepth(FixupContext *context)
{
    if (context->currentDepth <= 0) {
        return false;
    }
    context->currentDepth--;
    return true;
}

static bool
matchesPath(FixupContext *context, char **path, const char *finalName)
{
    if (finalName == NULL) {
        finalName = "";
    }

    for (int i = 0; i < context->currentDepth; i++) {
        if (strncmp(context->objectPath[i], path[i], MAX_NAME_LENGTH) != 0) {
            return false;
        }
    }
    if (strncmp(finalName, path[context->currentDepth], MAX_NAME_LENGTH) != 0) {
        return false;
    }
    return true;
}

static bool
matchesAPath(FixupContext *context, const char *name, char *paths[][MAX_DEPTH], int pathsCount)
{
    for (int i = 0; i < pathsCount; i++) {
        if (matchesPath(context, paths[i], name)) {
            return true;
        }
    }
    return false;
}

static bool
shouldFixDate(FixupContext *context, const char *name)
{
    return matchesAPath(context, name, datePaths, datePathsCount);
}

static int
onBooleanElement(const char *const name, const bool value, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    return sentrycrashjson_addBooleanElement(context->encodeContext, name, value);
}

static int
onFloatingPointElement(const char *const name, const double value, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    return sentrycrashjson_addFloatingPointElement(context->encodeContext, name, value);
}

static int
onIntegerElement(const char *const name, const int64_t value, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    int result = SentryCrashJSON_OK;
    if (shouldFixDate(context, name)) {
        char buffer[21];
        sentrycrashdate_utcStringFromTimestamp((time_t)value, buffer);

        result = sentrycrashjson_addStringElement(
            context->encodeContext, name, buffer, (int)strlen(buffer));
    } else {
        result = sentrycrashjson_addIntegerElement(context->encodeContext, name, value);
    }
    return result;
}

static int
onUIntegerElement(const char *const name, const uint64_t value, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    return sentrycrashjson_addUIntegerElement(context->encodeContext, name, value);
}

static int
onNullElement(const char *const name, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    return sentrycrashjson_addNullElement(context->encodeContext, name);
}

static int
onStringElement(const char *const name, const char *const value, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    const char *stringValue = value;

    int result = sentrycrashjson_addStringElement(
        context->encodeContext, name, stringValue, (int)strlen(stringValue));

    return result;
}

static int
onBeginObject(const char *const name, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    int result = sentrycrashjson_beginObject(context->encodeContext, name);
    if (!increaseDepth(context, name)) {
        return SentryCrashJSON_ERROR_DATA_TOO_LONG;
    }
    return result;
}

static int
onBeginArray(const char *const name, void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    int result = sentrycrashjson_beginArray(context->encodeContext, name);
    if (!increaseDepth(context, name)) {
        return SentryCrashJSON_ERROR_DATA_TOO_LONG;
    }
    return result;
}

static int
onEndContainer(void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    int result = sentrycrashjson_endContainer(context->encodeContext);
    if (!decreaseDepth(context)) {
        // Do something;
    }
    return result;
}

static int
onEndData(__unused void *const userData)
{
    FixupContext *context = (FixupContext *)userData;
    return sentrycrashjson_endEncode(context->encodeContext);
}

static int
addJSONData(const char *data, int length, void *userData)
{
    FixupContext *context = (FixupContext *)userData;
    if (length > context->outputBytesLeft) {
        return SentryCrashJSON_ERROR_DATA_TOO_LONG;
    }
    memcpy(context->outputPtr, data, length);
    context->outputPtr += length;
    context->outputBytesLeft -= length;

    return SentryCrashJSON_OK;
}

char *
sentrycrashcrf_fixupCrashReport(const char *crashReport)
{
    if (crashReport == NULL) {
        return NULL;
    }

    SentryCrashJSONDecodeCallbacks callbacks = {
        .onBeginArray = onBeginArray,
        .onBeginObject = onBeginObject,
        .onBooleanElement = onBooleanElement,
        .onEndContainer = onEndContainer,
        .onEndData = onEndData,
        .onFloatingPointElement = onFloatingPointElement,
        .onIntegerElement = onIntegerElement,
        .onUIntegerElement = onUIntegerElement,
        .onNullElement = onNullElement,
        .onStringElement = onStringElement,
    };
    int stringBufferLength = SentryCrashMAX_STRINGBUFFERSIZE;
    char *stringBuffer = malloc((unsigned)stringBufferLength);
    if (stringBuffer == NULL) {
        SentryCrashLOG_ERROR("Failed to allocate string buffer of size %ul", stringBufferLength);
        return NULL;
    }
    int crashReportLength = (int)strlen(crashReport);
    int fixedReportLength = (int)(crashReportLength * 1.5);
    char *fixedReport = malloc((unsigned)fixedReportLength);
    if (fixedReport == NULL) {
        free(stringBuffer);
        SentryCrashLOG_ERROR(
            "Failed to allocate fixed report buffer of size %ld", fixedReportLength);
        return NULL;
    }
    SentryCrashJSONEncodeContext encodeContext;
    FixupContext fixupContext = {
        .encodeContext = &encodeContext,
        .currentDepth = 0,
        .outputPtr = fixedReport,
        .outputBytesLeft = fixedReportLength,
    };

    sentrycrashjson_beginEncode(&encodeContext, true, addJSONData, &fixupContext);

    int errorOffset = 0;
    int result = sentrycrashjson_decode(crashReport, (int)strlen(crashReport), stringBuffer,
        stringBufferLength, &callbacks, &fixupContext, &errorOffset);
    *fixupContext.outputPtr = '\0';
    free(stringBuffer);
    if (result != SentryCrashJSON_OK) {
        SentryCrashLOG_ERROR("Could not decode report: %s", sentrycrashjson_stringForError(result));
        free(fixedReport);
        return NULL;
    }
    return fixedReport;
}
