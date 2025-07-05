// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMach-O.h
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

#ifndef SentryCrashMachO_h
#define SentryCrashMachO_h

#include <mach/vm_prot.h>

#include "SentryCrashPlatformSpecificDefines.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * This routine returns the `load_command` structure for the specified command type
 * if it exists in the passed mach header. Otherwise, it returns `NULL`.
 *
 * @param header Pointer to the mach_header structure.
 * @param command_type The type of the command to search for.
 * @return Pointer to the `load_command` structure if found, otherwise `NULL`.
 */
const struct load_command *sentrycrash_macho_getCommandByTypeFromHeader(
    const mach_header_t *header, uint32_t command_type);

/**
 * This routine returns the `segment_command` structure for the named segment
 * if it exists in the passed mach header. Otherwise, it returns `NULL`.
 * It just looks through the load commands. Since these are mapped into the text
 * segment, they are read-only and thus const.
 *
 * @param header Pointer to the mach_header structure.
 * @param seg_name The name of the segment to search for.
 * @return Pointer to the `segment_command` structure if found, otherwise `NULL`.
 */
const segment_command_t *sentrycrash_macho_getSegmentByNameFromHeader(
    const mach_header_t *header, const char *seg_name);

/**
 * This routine returns the section structure for the specified `SECTION_TYPE` flag
 * from mach-o/loader.h if it exists in the passed segment command. Otherwise, it returns `NULL`.
 *
 * @param dataSegment Pointer to the segment_command structure.
 * @param flag The `SECTION_TYPE` flag of the section to search for.
 * @return Pointer to the section structure if found, otherwise `NULL`.
 */
const section_t *sentrycrash_macho_getSectionByTypeFlagFromSegment(
    const segment_command_t *dataSegment, uint32_t flag);

/**
 * This routine returns the protection attributes for a given memory section.
 *
 * @param sectionStart Pointer to the start of the memory section.
 * @return Protection attributes of the section.
 */
vm_prot_t sentrycrash_macho_getSectionProtection(void *sectionStart);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* SentryCrash_h */
