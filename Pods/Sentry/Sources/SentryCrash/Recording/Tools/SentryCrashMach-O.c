// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMach-O.c
//
//  Copyright (c) 2019 YANDEX LLC. All rights reserved.
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
// Contains code of getsegbyname.c
// https://opensource.apple.com/source/cctools/cctools-921/libmacho/getsegbyname.c.auto.html
// Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
//
// @APPLE_LICENSE_HEADER_START@
//
// This file contains Original Code and/or Modifications of Original Code
// as defined in and that are subject to the Apple Public Source License
// Version 2.0 (the 'License'). You may not use this file except in
// compliance with the License. Please obtain a copy of the License at
// http://www.opensource.apple.com/apsl/ and read it before using this
// file.
//
// The Original Code and all software distributed under the License are
// distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
// EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
// INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
// Please see the License for the specific language governing rights and
// limitations under the License.
//
// @APPLE_LICENSE_HEADER_END@
//

#include "SentryCrashMach-O.h"

#include <mach-o/loader.h>
#include <mach/mach.h>
#include <string.h>
#include <sys/types.h>

#include "SentryAsyncSafeLog.h"

const struct load_command *
sentrycrash_macho_getCommandByTypeFromHeader(const mach_header_t *header, uint32_t commandType)
{
    if (header == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Header is NULL");
        return NULL;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE(
        "Getting command by type %u in Mach header at %p", commandType, header);

    uintptr_t current = (uintptr_t)header + sizeof(mach_header_t);
    struct load_command *loadCommand = NULL;

    for (uint commandIndex = 0; commandIndex < header->ncmds; commandIndex++) {
        loadCommand = (struct load_command *)current;
        if (loadCommand->cmd == commandType) {
            return loadCommand;
        }
        current += loadCommand->cmdsize;
    }
    SENTRY_ASYNC_SAFE_LOG_WARN("Command type %u not found", commandType);
    return NULL;
}

const segment_command_t *
sentrycrash_macho_getSegmentByNameFromHeader(const mach_header_t *header, const char *segmentName)
{
    if (header == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Header is NULL");
        return NULL;
    }

    if (segmentName == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Segment name is NULL");
        return NULL;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE(
        "Searching for segment %s in Mach header at %p", segmentName, header);

    const segment_command_t *segmentCommand;

    segmentCommand = (segment_command_t *)((uintptr_t)header + sizeof(mach_header_t));
    for (uint commandIndex = 0; commandIndex < header->ncmds; commandIndex++) {
        if (segmentCommand->cmd == LC_SEGMENT_ARCH_DEPENDENT
            && strncmp(segmentCommand->segname, segmentName, sizeof(segmentCommand->segname))
                == 0) {
            SENTRY_ASYNC_SAFE_LOG_DEBUG("Segment %s found at %p", segmentName, segmentCommand);
            return segmentCommand;
        }
        segmentCommand = (segment_command_t *)((uintptr_t)segmentCommand + segmentCommand->cmdsize);
    }

    SENTRY_ASYNC_SAFE_LOG_WARN("Segment %s not found in Mach header at %p", segmentName, header);
    return NULL;
}

const section_t *
sentrycrash_macho_getSectionByTypeFlagFromSegment(
    const segment_command_t *segmentCommand, uint32_t flag)
{
    if (segmentCommand == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Segment is NULL");
        return NULL;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE(
        "Getting section by flag %u in segment %s", flag, segmentCommand->segname);

    uintptr_t current = (uintptr_t)segmentCommand + sizeof(segment_command_t);
    const section_t *section = NULL;

    for (uint sectionIndex = 0; sectionIndex < segmentCommand->nsects; sectionIndex++) {
        section = (const section_t *)(current + sectionIndex * sizeof(section_t));
        if ((section->flags & SECTION_TYPE) == flag) {
            return section;
        }
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "Section with flag %u not found in segment %s", flag, segmentCommand->segname);
    return NULL;
}

vm_prot_t
sentrycrash_macho_getSectionProtection(void *sectionStart)
{
    SENTRY_ASYNC_SAFE_LOG_TRACE("Getting protection for section starting at %p", sectionStart);

    mach_port_t task = mach_task_self();
    vm_size_t size = 0;
    vm_address_t address = (vm_address_t)sectionStart;
    memory_object_name_t object;
#if __LP64__
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    vm_region_basic_info_data_64_t info;
    kern_return_t info_ret = vm_region_64(task, &address, &size, VM_REGION_BASIC_INFO_64,
        (vm_region_info_64_t)&info, &count, &object);
#else
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT;
    vm_region_basic_info_data_t info;
    kern_return_t info_ret = vm_region(
        task, &address, &size, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &count, &object);
#endif
    if (info_ret == KERN_SUCCESS) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Protection obtained: %d", info.protection);
        return info.protection;
    } else {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Failed to get protection for section: %s", mach_error_string(info_ret));
        return VM_PROT_READ;
    }
}
