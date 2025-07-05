// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashDynamicLinker.c
//
//  Created by Karl Stenerud on 2013-10-02.
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

#include "SentryCrashDynamicLinker.h"

#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach-o/getsect.h>
#include <mach-o/nlist.h>
#include <string.h>

#include "SentryAsyncSafeLog.h"
#include "SentryCrashMemory.h"
#include "SentryCrashPlatformSpecificDefines.h"

#ifndef SENTRYCRASHDL_MaxCrashInfoStringLength
#    define SENTRYCRASHDL_MaxCrashInfoStringLength 1024
#endif

#pragma pack(8)
typedef struct {
    unsigned version;
    const char *message;
    const char *signature;
    const char *backtrace;
    const char *message2;
    void *reserved;
    void *reserved2;
    void *reserved3; // First introduced in version 5
} crash_info_t;
#pragma pack()
#define SENTRYCRASHDL_SECT_CRASH_INFO "__crash_info"

// Cache for dyld header information
const struct mach_header *sentryDyldHeader = NULL;

/** Get the address of the first command following a header (which will be of
 * type struct load_command).
 *
 * @param header The header to get commands for.
 *
 * @return The address of the first command, or NULL if none was found (which
 *         should not happen unless the header or image is corrupt).
 */
uintptr_t
firstCmdAfterHeader(const struct mach_header *const header)
{
    switch (header->magic) {
    case MH_MAGIC:
    case MH_CIGAM:
        return (uintptr_t)(header + 1);
    case MH_MAGIC_64:
    case MH_CIGAM_64:
        return (uintptr_t)(((struct mach_header_64 *)header) + 1);
    default:
        // Header is corrupt
        return 0;
    }
}

/** Get the dyld all image infos structure for the current task.
 *
 * This function retrieves the dyld_all_image_infos structure which contains information
 * about all loaded images in the current task, including dyld itself. This is particularly
 * useful for accessing dyld information since it's no longer included in the regular
 * _dyld_image_count() and related functions.
 *
 * @return A pointer to the dyld_all_image_infos structure if successful, NULL otherwise.
 */
struct dyld_all_image_infos *
getAllImageInfo(void)
{
    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;

    kern_return_t kr = task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);

    if (kr != KERN_SUCCESS) {
        return NULL;
    }
    return (struct dyld_all_image_infos *)dyld_info.all_image_info_addr;
}

/** Initialize the dyld header cache.
 * This should be called once at startup.
 */
static void
initializeDyldHeader(void)
{
    if (sentryDyldHeader == NULL) {
        struct dyld_all_image_infos *infos = getAllImageInfo();
        if (infos && infos->dyldImageLoadAddress) {
            sentryDyldHeader = (const struct mach_header *)infos->dyldImageLoadAddress;
        }
    }
}

/** Get the segment command for a specific segment from a mach_header.
 *
 * @param header The mach_header to search in.
 * @param segmentName The name of the segment to find (e.g., "__TEXT").
 * @return Pointer to the segment command, or NULL if not found.
 */
static const sentry_segment_command_t *
getSegmentCommand(const struct mach_header *header, const char *segmentName)
{
    if (header == NULL || segmentName == NULL) {
        return NULL;
    }

    uintptr_t cmdPtr = firstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return NULL;
    }

    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        const struct load_command *loadCmd = (struct load_command *)cmdPtr;
        if (loadCmd->cmd == SENTRY_SEGMENT_TYPE) {
            const sentry_segment_command_t *segCmd = (sentry_segment_command_t *)cmdPtr;
            if (strcmp(segCmd->segname, segmentName) == 0) {
                return segCmd;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }

    return NULL;
}

/** Get the address information of a specific segment from a mach_header.
 *
 * @param header The mach_header to search in.
 * @param segmentName The name of the segment to find (e.g., "__TEXT").
 * @return Structure containing start, end, and size of the segment, or {0, 0, 0} if not found.
 */
SentrySegmentAddress
getSegmentAddress(const struct mach_header *header, const char *segmentName)
{
    SentrySegmentAddress result = { 0, 0 };

    const sentry_segment_command_t *segCmd = getSegmentCommand(header, segmentName);
    if (segCmd != NULL) {
        result.start = (uintptr_t)header + segCmd->vmaddr;
        result.size = segCmd->vmsize;
    }

    return result;
}

/** Get the image index that the specified address is part of.
 *
 * @param address The address to examine.
 * @return The index of the image it is part of, SENTRY_DYLD_INDEX if the address belongs to dyld,
 * or UINT_MAX if none was found.
 */
uint32_t
imageIndexContainingAddress(const uintptr_t address)
{
    const uint32_t imageCount = _dyld_image_count();
    const struct mach_header *header = 0;

    for (uint32_t iImg = 0; iImg < imageCount; iImg++) {
        header = _dyld_get_image_header(iImg);
        if (header != NULL) {
            // Look for a segment command with this address within its range.
            uintptr_t addressWSlide = address - (uintptr_t)_dyld_get_image_vmaddr_slide(iImg);
            uintptr_t cmdPtr = firstCmdAfterHeader(header);
            if (cmdPtr == 0) {
                continue;
            }
            for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
                const struct load_command *loadCmd = (struct load_command *)cmdPtr;
                if (loadCmd->cmd == SENTRY_SEGMENT_TYPE) {
                    const sentry_segment_command_t *segCmd = (sentry_segment_command_t *)cmdPtr;
                    if (addressWSlide >= segCmd->vmaddr
                        && addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        return iImg;
                    }
                }
                cmdPtr += loadCmd->cmdsize;
            }
        }
    }

    // Check if the address belongs to dyld using cached header
    if (sentryDyldHeader != NULL) {
        SentrySegmentAddress textSegment = getSegmentAddress(sentryDyldHeader, SEG_TEXT);
        if (textSegment.start != 0 && address >= textSegment.start
            && address < textSegment.start + textSegment.size) {
            return SENTRY_DYLD_INDEX;
        }
    }
    return UINT_MAX;
}

/** Get the segment base address of the specified image.
 *
 * This is required for any symtab command offsets.
 *
 * @param idx The image index.
 * @return The image's base address, or 0 if none was found.
 */
static uintptr_t
segmentBaseOfImageIndex(const uint32_t idx)
{
    const struct mach_header *header = _dyld_get_image_header(idx);
    const sentry_segment_command_t *segCmd = getSegmentCommand(header, SEG_LINKEDIT);
    if (segCmd != NULL) {
        return (uintptr_t)(segCmd->vmaddr - segCmd->fileoff);
    }
    return 0;
}

uint32_t
sentrycrashdl_imageNamed(const char *const imageName, bool exactMatch)
{
    if (imageName != NULL) {
        const uint32_t imageCount = _dyld_image_count();

        for (uint32_t iImg = 0; iImg < imageCount; iImg++) {
            const char *name = _dyld_get_image_name(iImg);
            if (exactMatch) {
                if (strcmp(name, imageName) == 0) {
                    return iImg;
                }
            } else {
                if (strstr(name, imageName) != NULL) {
                    return iImg;
                }
            }
        }
    }
    return UINT32_MAX;
}

const uint8_t *
sentrycrashdl_imageUUID(const char *const imageName, bool exactMatch)
{
    if (imageName != NULL) {
        const uint32_t iImg = sentrycrashdl_imageNamed(imageName, exactMatch);
        if (iImg != UINT32_MAX) {
            const struct mach_header *header = _dyld_get_image_header(iImg);
            if (header != NULL) {
                uintptr_t cmdPtr = firstCmdAfterHeader(header);
                if (cmdPtr != 0) {
                    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
                        const struct load_command *loadCmd = (struct load_command *)cmdPtr;
                        if (loadCmd->cmd == LC_UUID) {
                            struct uuid_command *uuidCmd = (struct uuid_command *)cmdPtr;
                            return uuidCmd->uuid;
                        }
                        cmdPtr += loadCmd->cmdsize;
                    }
                }
            }
        }
    }
    return NULL;
}

bool
sentrycrashdl_dladdr(const uintptr_t address, Dl_info *const info)
{
    info->dli_fname = NULL;
    info->dli_fbase = NULL;
    info->dli_sname = NULL;
    info->dli_saddr = NULL;

    const uint32_t idx = imageIndexContainingAddress(address);

    const struct mach_header *header = NULL;
    uintptr_t imageVMAddrSlide = 0;
    uintptr_t segmentBase = 0;

    if (idx == SENTRY_DYLD_INDEX) {
        // Handle dyld manually
        header = sentryDyldHeader;
        if (header == NULL) {
            return false;
        }

        // Calculate dyld slide from __TEXT vmaddr
        SentrySegmentAddress textSegment = getSegmentAddress(header, SEG_TEXT);
        uintptr_t vmaddr = textSegment.start;
        if (vmaddr != 0) {
            imageVMAddrSlide = (uintptr_t)header - vmaddr;
            segmentBase = (uintptr_t)header;
        }

        info->dli_fname = "dyld";
    } else if (idx != UINT_MAX) {
        // Normal image path
        header = _dyld_get_image_header(idx);
        imageVMAddrSlide = (uintptr_t)_dyld_get_image_vmaddr_slide(idx);
        segmentBase = segmentBaseOfImageIndex(idx) + imageVMAddrSlide;
        info->dli_fname = _dyld_get_image_name(idx);
    } else {
        return false;
    }
    const uintptr_t addressWithSlide = address - imageVMAddrSlide;
    if (segmentBase == 0) {
        return false;
    }

    info->dli_fbase = (void *)header;

    // Find symbol tables and get whichever symbol is closest to the address.
    const nlist_t *bestMatch = NULL;
    uintptr_t bestDistance = ULONG_MAX;
    uintptr_t cmdPtr = firstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return false;
    }
    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        const struct load_command *loadCmd = (struct load_command *)cmdPtr;
        if (loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command *symtabCmd = (struct symtab_command *)cmdPtr;
            const nlist_t *symbolTable = (nlist_t *)(segmentBase + symtabCmd->symoff);
            const uintptr_t stringTable = segmentBase + symtabCmd->stroff;

            for (uint32_t iSym = 0; iSym < symtabCmd->nsyms; iSym++) {
                // If n_value is 0, the symbol refers to an external object.
                if (symbolTable[iSym].n_value != 0) {
                    uintptr_t symbolBase = symbolTable[iSym].n_value;
                    uintptr_t currentDistance = addressWithSlide - symbolBase;
                    if ((addressWithSlide >= symbolBase) && (currentDistance <= bestDistance)) {
                        bestMatch = symbolTable + iSym;
                        bestDistance = currentDistance;
                    }
                }
            }
            if (bestMatch != NULL) {
                info->dli_saddr = (void *)(bestMatch->n_value + imageVMAddrSlide);
                if (bestMatch->n_desc == 16) {
                    // This image has been stripped. The name is meaningless,
                    // and almost certainly resolves to "_mh_execute_header"
                    info->dli_sname = NULL;
                } else {
                    info->dli_sname
                        = (char *)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                    if (*info->dli_sname == '_') {
                        info->dli_sname++;
                    }
                }
                break;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }

    return true;
}

static bool
isValidCrashInfoMessage(const char *str)
{
    if (str == NULL) {
        return false;
    }
    int maxReadableBytes
        = sentrycrashmem_maxReadableBytes(str, SENTRYCRASHDL_MaxCrashInfoStringLength + 1);
    if (maxReadableBytes == 0) {
        return false;
    }
    for (int i = 0; i < maxReadableBytes; ++i) {
        if (str[i] == 0) {
            return true;
        }
    }
    return false;
}

/**
 * Get the message of fatalError, assert, and precondition to set it as the exception value if the
 * crashInfo contains the message.
 *
 * Swift puts the messages of fatalError, assert, and precondition into the @c crashInfo of the
 * @c libswiftCore.dylib. We found proof that the swift runtime uses @c __crash_info:
 * fatalError (1) calls @c swift_reportError (2) calls @c reportOnCrash (3) which uses (4) the
 * @c __crash_info (5). The documentation of Apple and Swift doesn't mention anything about where
 * the @c __crash_info ends up. Trying fatalError, assert, and precondition on iPhone, iPhone
 * simulator, and macOS all showed that the message ends up in the crashInfo of the
 * @c libswiftCore.dylib. For example, on the simulator, other binary images also contain a
 * @c crash_info_message with information about the stacktrace. We only care about the message of
 * fatalError, assert, or precondition, and we already get the stacktrace from the threads,
 * retrieving it from @c libswiftCore.dylib seems to be the most reliable option.
 *
 * @seealso
 * https://github.com/apple/swift/blob/d1bb98b11ede375a1cee739f964b7d23b6657aaf/stdlib/public/runtime/Errors.cpp#L365-L377
 * @seealso
 * https://github.com/apple/swift/blob/d1bb98b11ede375a1cee739f964b7d23b6657aaf/stdlib/public/runtime/Errors.cpp#L361
 * @seealso
 * https://github.com/apple/swift/blob/d1bb98b11ede375a1cee739f964b7d23b6657aaf/stdlib/public/runtime/Errors.cpp#L269-L293
 * @seealso
 * https://github.com/apple/swift/blob/d1bb98b11ede375a1cee739f964b7d23b6657aaf/stdlib/public/runtime/Errors.cpp#L264-L293
 * @seealso
 * https://github.com/apple/swift/blob/d1bb98b11ede375a1cee739f964b7d23b6657aaf/include/swift/Runtime/Debug.h#L29-L58
 *
 * We also investigated using getsectbynamefromheader to get the crash info as Crashlytics
 * (https://github.com/firebase/firebase-ios-sdk/blob/main/Crashlytics/Crashlytics/Components/FIRCLSBinaryImage.m#L245-L283)
 * does it, but we get the same results. If the crash info is missing, we can't find it via
 * getsectiondata or getsectbynamefromheader. We also saw Swift storing the error message into the
 * x26 CPU register, but when the error message isn't in the crash info, we also can't find it in
 * the x26 CPU register. Furthermore, the error message gets truncated. For example:
 *
 * Fatal error: Duplicate keys of type 'Something' were found in a Dictionary.\nThis usually means
 * either that the type violates Hashable's requirements, or\nthat members of such a dictionary were
 * mutated after insertion.
 *
 * gets truncated to
 *
 * ' were found in a Dictionary.\nThis usually means either that the type violates Hashable's
 * requirements, or\nthat members of such a dictionary were mutated after insertion.
 *
 * So, there seems to be a problem with the string interpolation.
 */
static void
getCrashInfo(const struct mach_header *header, SentryCrashBinaryImage *buffer)
{
    unsigned long size = 0;
    crash_info_t *crashInfo = (crash_info_t *)getsectiondata(
        (mach_header_t *)header, SEG_DATA, SENTRYCRASHDL_SECT_CRASH_INFO, &size);
    if (crashInfo == NULL) {
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE("Found crash info section in binary: %s", buffer->name);
    const unsigned int minimalSize
        = offsetof(crash_info_t, reserved); // Include message and message2
    if (size < minimalSize) {
        SENTRY_ASYNC_SAFE_LOG_TRACE("Skipped reading crash info: section is too small");
        return;
    }
    if (!sentrycrashmem_isMemoryReadable(crashInfo, minimalSize)) {
        SENTRY_ASYNC_SAFE_LOG_TRACE("Skipped reading crash info: section memory is not readable");
        return;
    }
    if (crashInfo->version != 4 && crashInfo->version != 5) {
        SENTRY_ASYNC_SAFE_LOG_TRACE(
            "Skipped reading crash info: invalid version '%d'", crashInfo->version);
        return;
    }
    if (crashInfo->message == NULL && crashInfo->message2 == NULL) {
        SENTRY_ASYNC_SAFE_LOG_TRACE("Skipped reading crash info: both messages are null");
        return;
    }

    if (isValidCrashInfoMessage(crashInfo->message)) {
        SENTRY_ASYNC_SAFE_LOG_TRACE("Found first message: %s", crashInfo->message);
        buffer->crashInfoMessage = crashInfo->message;
    }
    if (isValidCrashInfoMessage(crashInfo->message2)) {
        SENTRY_ASYNC_SAFE_LOG_TRACE("Found second message: %s", crashInfo->message2);
        buffer->crashInfoMessage2 = crashInfo->message2;
    }
}

int
sentrycrashdl_imageCount(void)
{
    return (int)_dyld_image_count();
}

bool
sentrycrashdl_getBinaryImage(int index, SentryCrashBinaryImage *buffer, bool isCrash)
{
    const struct mach_header *header = _dyld_get_image_header((unsigned)index);
    if (header == NULL) {
        return false;
    }

    const char *imageName = _dyld_get_image_name((unsigned)index);
    return sentrycrashdl_getBinaryImageForHeader((const void *)header, imageName, buffer, isCrash);
}

void
sentrycrashdl_getCrashInfo(uint64_t address, SentryCrashBinaryImage *buffer)
{
    getCrashInfo((struct mach_header *)address, buffer);
}

bool
sentrycrashdl_getBinaryImageForHeader(const void *const header_ptr, const char *const image_name,
    SentryCrashBinaryImage *buffer, bool isCrash)
{
    const struct mach_header *header = (const struct mach_header *)header_ptr;
    uintptr_t cmdPtr = firstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return false;
    }

    // Look for the TEXT segment to get the image size.
    // Also look for a UUID command.
    uint64_t imageSize = 0;
    uint64_t imageVmAddr = 0;
    uint8_t *uuid = NULL;

    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        struct load_command *loadCmd = (struct load_command *)cmdPtr;
        switch (loadCmd->cmd) {
        case SENTRY_SEGMENT_TYPE: {
            sentry_segment_command_t *segCmd = (sentry_segment_command_t *)cmdPtr;
            if (strcmp(segCmd->segname, SEG_TEXT) == 0) {
                imageSize = segCmd->vmsize;
                imageVmAddr = segCmd->vmaddr;
            }
            break;
        }
        case LC_UUID: {
            struct uuid_command *uuidCmd = (struct uuid_command *)cmdPtr;
            uuid = uuidCmd->uuid;
            break;
        }
        }
        cmdPtr += loadCmd->cmdsize;
    }

    buffer->address = (uintptr_t)header;
    buffer->vmAddress = imageVmAddr;
    buffer->size = imageSize;
    buffer->name = image_name;
    buffer->uuid = uuid;
    buffer->cpuType = header->cputype;
    buffer->cpuSubType = header->cpusubtype;
    if (isCrash) {
        getCrashInfo(header, buffer);
    }

    return true;
}

void
sentrycrashdl_initialize(void)
{
    initializeDyldHeader();
}

void
sentrycrashdl_clearDyld(void)
{
    sentryDyldHeader = NULL;
}
