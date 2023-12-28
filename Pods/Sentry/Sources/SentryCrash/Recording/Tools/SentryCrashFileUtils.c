// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashFileUtils.c
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

#include "SentryCrashFileUtils.h"

// #define SentryCrashLogger_LocalLevel TRACE
#include "SentryCrashLogger.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/** Buffer size to use in the "writeFmt" functions.
 * If the formatted output length would exceed this value, it is truncated.
 */
#ifndef SentryCrashFU_WriteFmtBufferSize
#    define SentryCrashFU_WriteFmtBufferSize 1024
#endif

// ============================================================================
#pragma mark - Utility -
// ============================================================================

static bool
canDeletePath(const char *path)
{
    const char *lastComponent = strrchr(path, '/');
    if (lastComponent == NULL) {
        lastComponent = path;
    } else {
        lastComponent++;
    }
    if (strcmp(lastComponent, ".") == 0) {
        return false;
    }
    if (strcmp(lastComponent, "..") == 0) {
        return false;
    }
    return true;
}

static int
dirContentsCount(const char *path)
{
    int count = 0;
    DIR *dir = opendir(path);
    if (dir == NULL) {
        SentryCrashLOG_ERROR("Error reading directory %s: %s", path, strerror(errno));
        return 0;
    }

    while (readdir(dir)) {
        count++;
    }

    closedir(dir);
    return count;
}

static void
dirContents(const char *path, char ***entries, int *count)
{
    DIR *dir = NULL;
    char **entryList = NULL;
    int entryCount = dirContentsCount(path);
    if (entryCount <= 0) {
        goto done;
    }
    dir = opendir(path);
    if (dir == NULL) {
        SentryCrashLOG_ERROR("Error reading directory %s: %s", path, strerror(errno));
        goto done;
    }

    entryList = calloc((unsigned)entryCount, sizeof(char *));
    if (entryList != NULL) {
        struct dirent *ent;
        int index = 0;
        while ((ent = readdir(dir))) {
            if (index >= entryCount) {
                SentryCrashLOG_ERROR("Contents of %s have been mutated", path);
                goto done;
            }
            entryList[index] = strdup(ent->d_name);
            index++;
        }
    }

done:
    if (dir != NULL) {
        closedir(dir);
    }
    if (entryList == NULL) {
        entryCount = 0;
    }
    *entries = entryList;
    *count = entryCount;
}

static void
freeDirListing(char **entries, int count)
{
    if (entries != NULL) {
        for (int i = 0; i < count; i++) {
            char *ptr = entries[i];
            if (ptr != NULL) {
                free(ptr);
            }
        }
        free(entries);
    }
}

static bool
deletePathContents(const char *path, bool deleteTopLevelPathAlso)
{
    struct stat statStruct = { 0 };
    if (stat(path, &statStruct) != 0) {
        SentryCrashLOG_ERROR("Could not stat %s: %s", path, strerror(errno));
        return false;
    }
    if (S_ISDIR(statStruct.st_mode)) {
        char **entries = NULL;
        int entryCount = 0;
        dirContents(path, &entries, &entryCount);

        int bufferLength = SentryCrashFU_MAX_PATH_LENGTH;
        char *pathBuffer = malloc((unsigned)bufferLength);
        snprintf(pathBuffer, bufferLength, "%s/", path);
        char *pathPtr = pathBuffer + strlen(pathBuffer);
        int pathRemainingLength = bufferLength - (int)(pathPtr - pathBuffer);

        for (int i = 0; i < entryCount; i++) {
            char *entry = entries[i];
            if (entry != NULL && canDeletePath(entry)) {
                strncpy(pathPtr, entry, pathRemainingLength);
                deletePathContents(pathBuffer, true);
            }
        }

        free(pathBuffer);
        freeDirListing(entries, entryCount);
        if (deleteTopLevelPathAlso) {
            sentrycrashfu_removeFile(path, false);
        }
    } else if (S_ISREG(statStruct.st_mode)) {
        sentrycrashfu_removeFile(path, false);
    } else {
        SentryCrashLOG_ERROR("Could not delete %s: Not a regular file.", path);
        return false;
    }
    return true;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

const char *
sentrycrashfu_lastPathEntry(const char *const path)
{
    if (path == NULL) {
        return NULL;
    }

    char *lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

bool
sentrycrashfu_writeBytesToFD(const int fd, const char *const bytes, int length)
{
    const char *pos = bytes;
    while (length > 0) {
        int bytesWritten = (int)write(fd, pos, (unsigned)length);
        if (bytesWritten == -1) {
            SentryCrashLOG_ERROR("Could not write to fd %d: %s", fd, strerror(errno));
            return false;
        }
        length -= bytesWritten;
        pos += bytesWritten;
    }
    return true;
}

bool
sentrycrashfu_readBytesFromFD(const int fd, char *const bytes, int length)
{
    char *pos = bytes;
    while (length > 0) {
        int bytesRead = (int)read(fd, pos, (unsigned)length);
        if (bytesRead == -1) {
            SentryCrashLOG_ERROR("Could not write to fd %d: %s", fd, strerror(errno));
            return false;
        }
        length -= bytesRead;
        pos += bytesRead;
    }
    return true;
}

bool
sentrycrashfu_readEntireFile(const char *const path, char **data, int *length, int maxLength)
{
    bool isSuccessful = false;
    int bytesRead = 0;
    char *mem = NULL;
    int fd = -1;
    int bytesToRead = maxLength;

    struct stat st;
    if (stat(path, &st) < 0) {
        SentryCrashLOG_ERROR("Could not stat %s: %s", path, strerror(errno));
        goto done;
    }

    fd = open(path, O_RDONLY);
    if (fd < 0) {
        SentryCrashLOG_ERROR("Could not open %s: %s", path, strerror(errno));
        goto done;
    }

    if (bytesToRead == 0 || bytesToRead >= (int)st.st_size) {
        bytesToRead = (int)st.st_size;
    } else if (bytesToRead > 0) {
        if (lseek(fd, -bytesToRead, SEEK_END) < 0) {
            SentryCrashLOG_ERROR(
                "Could not seek to %d from end of %s: %s", -bytesToRead, path, strerror(errno));
            goto done;
        }
    }

    mem = malloc((unsigned)bytesToRead + 1);
    if (mem == NULL) {
        SentryCrashLOG_ERROR("Out of memory");
        goto done;
    }

    if (!sentrycrashfu_readBytesFromFD(fd, mem, bytesToRead)) {
        goto done;
    }

    bytesRead = bytesToRead;
    mem[bytesRead] = '\0';
    isSuccessful = true;

done:
    if (fd >= 0) {
        close(fd);
    }
    if (!isSuccessful && mem != NULL) {
        free(mem);
        mem = NULL;
    }

    *data = mem;
    if (length != NULL) {
        *length = bytesRead;
    }

    return isSuccessful;
}

bool
sentrycrashfu_writeStringToFD(const int fd, const char *const string)
{
    if (*string != 0) {
        int bytesToWrite = (int)strlen(string);
        const char *pos = string;
        while (bytesToWrite > 0) {
            int bytesWritten = (int)write(fd, pos, (unsigned)bytesToWrite);
            if (bytesWritten == -1) {
                SentryCrashLOG_ERROR("Could not write to fd %d: %s", fd, strerror(errno));
                return false;
            }
            bytesToWrite -= bytesWritten;
            pos += bytesWritten;
        }
        return true;
    }
    return false;
}

bool
sentrycrashfu_writeFmtToFD(const int fd, const char *const fmt, ...)
{
    if (*fmt != 0) {
        va_list args;
        va_start(args, fmt);
        bool result = sentrycrashfu_writeFmtArgsToFD(fd, fmt, args);
        va_end(args);
        return result;
    }
    return false;
}

bool
sentrycrashfu_writeFmtArgsToFD(const int fd, const char *const fmt, va_list args)
{
    if (*fmt != 0) {
        char buffer[SentryCrashFU_WriteFmtBufferSize];
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        return sentrycrashfu_writeStringToFD(fd, buffer);
    }
    return false;
}

int
sentrycrashfu_readLineFromFD(const int fd, char *const buffer, const int maxLength)
{
    char *end = buffer + maxLength - 1;
    *end = 0;
    char *ch;
    for (ch = buffer; ch < end; ch++) {
        int bytesRead = (int)read(fd, ch, 1);
        if (bytesRead < 0) {
            SentryCrashLOG_ERROR("Could not read from fd %d: %s", fd, strerror(errno));
            return -1;
        } else if (bytesRead == 0 || *ch == '\n') {
            break;
        }
    }
    *ch = 0;
    return (int)(ch - buffer);
}

bool
sentrycrashfu_makePath(const char *absolutePath)
{
    bool isSuccessful = false;
    char *pathCopy = strdup(absolutePath);
    for (char *ptr = pathCopy + 1; *ptr != '\0'; ptr++) {
        if (*ptr == '/') {
            *ptr = '\0';
            if (mkdir(pathCopy, S_IRWXU) < 0 && errno != EEXIST) {
                SentryCrashLOG_ERROR(
                    "Could not create directory %s: %s", pathCopy, strerror(errno));
                goto done;
            }
            *ptr = '/';
        }
    }
    if (mkdir(pathCopy, S_IRWXU) < 0 && errno != EEXIST) {
        SentryCrashLOG_ERROR("Could not create directory %s: %s", pathCopy, strerror(errno));
        goto done;
    }
    isSuccessful = true;

done:
    free(pathCopy);
    return isSuccessful;
}

bool
sentrycrashfu_removeFile(const char *path, bool mustExist)
{
    if (remove(path) < 0) {
        if (mustExist || errno != ENOENT) {
            SentryCrashLOG_ERROR("Could not delete %s: %s", path, strerror(errno));
        }
        return false;
    }
    return true;
}

bool
sentrycrashfu_deleteContentsOfPath(const char *path)
{
    if (!canDeletePath(path)) {
        return false;
    }

    return deletePathContents(path, false);
}

bool
sentrycrashfu_openBufferedWriter(SentryCrashBufferedWriter *writer, const char *const path,
    char *writeBuffer, int writeBufferLength)
{
    writer->buffer = writeBuffer;
    writer->bufferLength = writeBufferLength;
    writer->position = 0;
    writer->fd = open(path, O_RDWR | O_CREAT | O_EXCL, 0644);
    if (writer->fd < 0) {
        SentryCrashLOG_ERROR("Could not open crash report file %s: %s", path, strerror(errno));
        return false;
    }
    return true;
}

void
sentrycrashfu_closeBufferedWriter(SentryCrashBufferedWriter *writer)
{
    if (writer->fd > 0) {
        sentrycrashfu_flushBufferedWriter(writer);
        close(writer->fd);
        writer->fd = -1;
    }
}

bool
sentrycrashfu_writeBufferedWriter(
    SentryCrashBufferedWriter *writer, const char *restrict const data, const int length)
{
    if (length > writer->bufferLength - writer->position) {
        sentrycrashfu_flushBufferedWriter(writer);
    }
    if (length > writer->bufferLength) {
        return sentrycrashfu_writeBytesToFD(writer->fd, data, length);
    }
    memcpy(writer->buffer + writer->position, data, length);
    writer->position += length;
    return true;
}

bool
sentrycrashfu_flushBufferedWriter(SentryCrashBufferedWriter *writer)
{
    if (writer->fd > 0 && writer->position > 0) {
        if (!sentrycrashfu_writeBytesToFD(writer->fd, writer->buffer, writer->position)) {
            return false;
        }
        writer->position = 0;
    }
    return true;
}

static inline bool
isReadBufferEmpty(SentryCrashBufferedReader *reader)
{
    return reader->dataEndPos == reader->dataStartPos;
}

static bool
fillReadBuffer(SentryCrashBufferedReader *reader)
{
    if (reader->dataStartPos > 0) {
        memmove(reader->buffer, reader->buffer + reader->dataStartPos, reader->dataStartPos);
        reader->dataEndPos -= reader->dataStartPos;
        reader->dataStartPos = 0;
        reader->buffer[reader->dataEndPos] = '\0';
    }
    int bytesToRead = reader->bufferLength - reader->dataEndPos;
    if (bytesToRead <= 0) {
        return true;
    }
    int bytesRead = (int)read(reader->fd, reader->buffer + reader->dataEndPos, (size_t)bytesToRead);
    if (bytesRead < 0) {
        SentryCrashLOG_ERROR("Could not read: %s", strerror(errno));
        return false;
    } else {
        reader->dataEndPos += bytesRead;
        reader->buffer[reader->dataEndPos] = '\0';
    }
    return true;
}

int
sentrycrashfu_readBufferedReader(SentryCrashBufferedReader *reader, char *dstBuffer, int byteCount)
{
    int bytesRemaining = byteCount;
    int bytesConsumed = 0;
    char *pDst = dstBuffer;
    while (bytesRemaining > 0) {
        int bytesInReader = reader->dataEndPos - reader->dataStartPos;
        if (bytesInReader <= 0) {
            if (!fillReadBuffer(reader)) {
                break;
            }
            bytesInReader = reader->dataEndPos - reader->dataStartPos;
            if (bytesInReader <= 0) {
                break;
            }
        }
        int bytesToCopy = bytesInReader <= bytesRemaining ? bytesInReader : bytesRemaining;
        char *pSrc = reader->buffer + reader->dataStartPos;
        memcpy(pDst, pSrc, bytesToCopy);
        pDst += bytesToCopy;
        reader->dataStartPos += bytesToCopy;
        bytesConsumed += bytesToCopy;
        bytesRemaining -= bytesToCopy;
    }

    return bytesConsumed;
}

bool
sentrycrashfu_readBufferedReaderUntilChar(
    SentryCrashBufferedReader *reader, int ch, char *dstBuffer, int *length)
{
    int bytesRemaining = *length;
    int bytesConsumed = 0;
    char *pDst = dstBuffer;
    while (bytesRemaining > 0) {
        int bytesInReader = reader->dataEndPos - reader->dataStartPos;
        int bytesToCopy = bytesInReader <= bytesRemaining ? bytesInReader : bytesRemaining;
        char *pSrc = reader->buffer + reader->dataStartPos;
        char *pChar = strchr(pSrc, ch);
        bool isFound = pChar != NULL;
        if (isFound) {
            int bytesToChar = (int)(pChar - pSrc) + 1;
            if (bytesToChar < bytesToCopy) {
                bytesToCopy = bytesToChar;
            }
        }
        memcpy(pDst, pSrc, bytesToCopy);
        pDst += bytesToCopy;
        reader->dataStartPos += bytesToCopy;
        bytesConsumed += bytesToCopy;
        bytesRemaining -= bytesToCopy;
        if (isFound) {
            *length = bytesConsumed;
            return true;
        }
        if (bytesRemaining > 0) {
            fillReadBuffer(reader);
            if (isReadBufferEmpty(reader)) {
                break;
            }
        }
    }

    *length = bytesConsumed;
    return false;
}

bool
sentrycrashfu_openBufferedReader(SentryCrashBufferedReader *reader, const char *const path,
    char *readBuffer, int readBufferLength)
{
    readBuffer[0] = '\0';
    readBuffer[readBufferLength - 1] = '\0';
    reader->buffer = readBuffer;
    reader->bufferLength = readBufferLength - 1;
    reader->dataStartPos = 0;
    reader->dataEndPos = 0;
    reader->fd = open(path, O_RDONLY);
    if (reader->fd < 0) {
        SentryCrashLOG_ERROR("Could not open file %s: %s", path, strerror(errno));
        return false;
    }
    fillReadBuffer(reader);
    return true;
}

void
sentrycrashfu_closeBufferedReader(SentryCrashBufferedReader *reader)
{
    if (reader->fd > 0) {
        close(reader->fd);
        reader->fd = -1;
    }
}
