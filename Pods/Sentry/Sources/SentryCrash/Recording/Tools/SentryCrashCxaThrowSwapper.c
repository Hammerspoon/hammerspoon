// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCxaThrowSwapper.cpp
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
//
// Inspired by facebook/fishhook
// https://github.com/facebook/fishhook
//
// Copyright (c) 2013, Facebook, Inc.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   * Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   * Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//   * Neither the name Facebook nor the names of its contributors may be used to
//     endorse or promote products derived from this software without specific
//     prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include "SentryCrashCxaThrowSwapper.h"

#include <dlfcn.h>
#include <errno.h>
#include <execinfo.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>

#include "SentryAsyncSafeLog.h"
#include "SentryCrashMach-O.h"
#include "SentryCrashPlatformSpecificDefines.h"

typedef struct {
    uintptr_t image_dli_fbase_address;
    uintptr_t cxa_throw_original_function;
} SentryCrashImageToOriginalCxaThrowPair;

static cxa_throw_type g_cxa_throw_handler = NULL;
static const char *const g_cxa_throw_name = "__cxa_throw";

static SentryCrashImageToOriginalCxaThrowPair *g_cxa_originals = NULL;
static size_t g_cxa_originals_capacity = 0;
static size_t g_cxa_originals_count = 0;

static uintptr_t
findOriginalCxaThrowFunction(uintptr_t image_dli_fbase_address)
{
    SENTRY_ASYNC_SAFE_LOG_TRACE(
        "Finding original __cxa_throw for image with base address %p", image_dli_fbase_address);

    for (size_t i = 0; i < g_cxa_originals_count; i++) {
        if (g_cxa_originals[i].image_dli_fbase_address == image_dli_fbase_address) {
            return g_cxa_originals[i].cxa_throw_original_function;
        }
    }
    SENTRY_ASYNC_SAFE_LOG_WARN("Address %p not found", image_dli_fbase_address);
    return (uintptr_t)NULL;
}

static void
addPair(SentryCrashImageToOriginalCxaThrowPair pair)
{
    uintptr_t originalCxaThrowFunction = findOriginalCxaThrowFunction(pair.image_dli_fbase_address);
    if (originalCxaThrowFunction != (uintptr_t)NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Already added address pair with image with base address: %p, "
                                    "and originalCxaThrowFunction: %p",
            (void *)pair.cxa_throw_original_function, (void *)pair.cxa_throw_original_function);
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "Adding pair for image with base address: %p, and originalCxaThrowFunction: %p",
        (void *)pair.image_dli_fbase_address, (void *)pair.cxa_throw_original_function);

    if (g_cxa_originals_count == g_cxa_originals_capacity) {
        g_cxa_originals_capacity *= 2;

        g_cxa_originals = (SentryCrashImageToOriginalCxaThrowPair *)realloc(g_cxa_originals,
            sizeof(SentryCrashImageToOriginalCxaThrowPair) * g_cxa_originals_capacity);

        // Strictly speaking we should use a temp variable for g_cxa_originals and free
        // g_cxa_originals in case realloc fails. But if realloc fails for such a small structure
        // the leak we're causing here is negligible. Ideally, we would need to escalate this and
        // return an error, because we would free the global structure g_cxa_originals. We
        // intentionally ignore this edge case in the first iteration of this code.

        if (g_cxa_originals == NULL) {
            SENTRY_ASYNC_SAFE_LOG_ERROR(
                "Failed to realloc memory for g_cxa_originals: %s", strerror(errno));
            return;
        }
    }
    memcpy(&g_cxa_originals[g_cxa_originals_count++], &pair,
        sizeof(SentryCrashImageToOriginalCxaThrowPair));
}

static void
__cxa_throw_decorator(void *thrown_exception, void *tinfo, void (*dest)(void *))
{
#define REQUIRED_FRAMES 2

    if (g_cxa_throw_handler != NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Not calling __cxa_throw decorator, because no g_cxa_throw_handler set.");
        g_cxa_throw_handler(thrown_exception, tinfo, dest);
    }

    void *backtraceArr[REQUIRED_FRAMES];
    int count = backtrace(backtraceArr, REQUIRED_FRAMES);

    Dl_info info;
    if (count < REQUIRED_FRAMES) {
        // This can happen if the throw happened in a signal handler. This is an edge case we ignore
        // for now. It can also happen with concurrency frameworks for which backtrace does not work
        // reliably, such as Swift async. It can be that we have to use backtrace_async which uses
        // the Swift concurrency continuation stack if invoked from within an async context. Again
        // we ignore this edge case for now.

        // Returning early here and not calling cxa_throw is fatal, but we cannot do anything else.
        SENTRY_ASYNC_SAFE_LOG_ERROR("Received only %d frames from backtrace. We can't identify "
                                    "throwsite and therefore can't call the original cxa_throw.",
            count);
        return;
    }

    if (dladdr(backtraceArr[REQUIRED_FRAMES - 1], &info) == 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "dladdr failed for throwsite. Can't identify image of throwsite.");
        return;
    }

    uintptr_t function = findOriginalCxaThrowFunction((uintptr_t)info.dli_fbase);
    if (function == (uintptr_t)NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Can't find original cxa_throw for the image of the throwsite.");
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE("Calling original __cxa_throw function at %p", (void *)function);
    cxa_throw_type original = (cxa_throw_type)function;
    original(thrown_exception, tinfo, dest);
}

static void
perform_rebinding_with_section(const section_t *dataSection, intptr_t slide, nlist_t *symtab,
    char *strtab, uint32_t *indirect_symtab, bool is_swapping_cxa_throw)
{
    SENTRY_ASYNC_SAFE_LOG_TRACE(
        "Processing section %s,%s", dataSection->segname, dataSection->sectname);

    uint32_t *indirect_symbol_indices = indirect_symtab + dataSection->reserved1;
    void **indirect_symbol_bindings = (void **)((uintptr_t)slide + dataSection->addr);

    // The SEG_DATA_CONST is read-only by default, so we need to make it writable
    // before we can modify the indirect symbol bindings.
    const bool isDataConst = strcmp(dataSection->segname, SEG_DATA_CONST) == 0;

    // As the default protection for the SEG_DATA_CONST is read-only we set the default
    // oldProtection to VM_PROT_READ.
    vm_prot_t oldProtection = VM_PROT_READ;
    if (isDataConst) {
        oldProtection = sentrycrash_macho_getSectionProtection(indirect_symbol_bindings);
        if (mprotect(indirect_symbol_bindings, dataSection->size, PROT_READ | PROT_WRITE) != 0) {
            SENTRY_ASYNC_SAFE_LOG_DEBUG(
                "mprotect failed to set PROT_READ | PROT_WRITE for section %s,%s: %s",
                dataSection->segname, dataSection->sectname, strerror(errno));
            return;
        }
    }

    for (uint i = 0; i < dataSection->size / sizeof(void *); i++) {
        uint32_t symtab_index = indirect_symbol_indices[i];
        if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL
            || symtab_index == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        bool symbol_name_longer_than_1 = symbol_name[0] && symbol_name[1];
        if (symbol_name_longer_than_1 && strcmp(&symbol_name[1], g_cxa_throw_name) == 0) {
            Dl_info info;
            if (dladdr(dataSection, &info) != 0) {
                if (is_swapping_cxa_throw) {
                    // Swapping: Store original and set new handler
                    SentryCrashImageToOriginalCxaThrowPair pair
                        = { (uintptr_t)info.dli_fbase, (uintptr_t)indirect_symbol_bindings[i] };
                    addPair(pair);
                    indirect_symbol_bindings[i] = (void *)__cxa_throw_decorator;
                    SENTRY_ASYNC_SAFE_LOG_TRACE("Swapped __cxa_throw function at %p with decorator",
                        (void *)indirect_symbol_bindings[i]);
                } else {
                    // Unswapping: Restore original handler
                    uintptr_t original_function
                        = findOriginalCxaThrowFunction((uintptr_t)info.dli_fbase);
                    if (original_function != (uintptr_t)NULL) {
                        indirect_symbol_bindings[i] = (void *)original_function;
                        SENTRY_ASYNC_SAFE_LOG_TRACE("Restored original __cxa_throw function at %p",
                            (void *)original_function);
                    } else {
                        SENTRY_ASYNC_SAFE_LOG_WARN("Can't unswap orignal __cxa_throw function for "
                                                   "image with base address %p",
                            (void *)info.dli_fbase);
                    }
                }
            }
        }
    }

    if (isDataConst) {
        int protection = 0;
        if (oldProtection & VM_PROT_READ) {
            protection |= PROT_READ;
        }
        if (oldProtection & VM_PROT_WRITE) {
            protection |= PROT_WRITE;
        }
        if (oldProtection & VM_PROT_EXECUTE) {
            protection |= PROT_EXEC;
        }
        if (mprotect(indirect_symbol_bindings, dataSection->size, protection) != 0) {
            SENTRY_ASYNC_SAFE_LOG_ERROR(
                "mprotect failed to restore protection for section %s,%s: %s", dataSection->segname,
                dataSection->sectname, strerror(errno));
        }
    }
}

static void
process_segment(const struct mach_header *header, intptr_t slide, const char *segname,
    nlist_t *symtab, char *strtab, uint32_t *indirect_symtab, bool is_swapping_cxa_throw)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Processing segment %s", segname);

    const segment_command_t *segment
        = sentrycrash_macho_getSegmentByNameFromHeader((mach_header_t *)header, segname);
    if (segment != NULL) {
        const section_t *lazy_sym_sect
            = sentrycrash_macho_getSectionByTypeFlagFromSegment(segment, S_LAZY_SYMBOL_POINTERS);
        const section_t *non_lazy_sym_sect = sentrycrash_macho_getSectionByTypeFlagFromSegment(
            segment, S_NON_LAZY_SYMBOL_POINTERS);

        if (lazy_sym_sect != NULL) {
            perform_rebinding_with_section(
                lazy_sym_sect, slide, symtab, strtab, indirect_symtab, is_swapping_cxa_throw);
        }
        if (non_lazy_sym_sect != NULL) {
            perform_rebinding_with_section(
                non_lazy_sym_sect, slide, symtab, strtab, indirect_symtab, is_swapping_cxa_throw);
        }
    } else {
        SENTRY_ASYNC_SAFE_LOG_WARN("Segment %s not found", segname);
    }
}

static void
rebind_symbols_for_image(
    const struct mach_header *header, intptr_t slide, bool is_swapping_cxa_throw)
{
    if (header == NULL) {
        SENTRY_ASYNC_SAFE_LOG_WARN("Header is NULL, cannot rebind symbols.");
        return;
    }

    if (slide == 0) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Slide is zero, cannot rebind symbols.");
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE("Rebinding symbols for image with slide %p", (void *)slide);

    Dl_info info;
    if (dladdr(header, &info) == 0) {
        SENTRY_ASYNC_SAFE_LOG_WARN("dladdr failed");
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Image name: %s", info.dli_fname);

    const struct symtab_command *symtab_cmd
        = (struct symtab_command *)sentrycrash_macho_getCommandByTypeFromHeader(
            (const mach_header_t *)header, LC_SYMTAB);
    const struct dysymtab_command *dysymtab_cmd
        = (struct dysymtab_command *)sentrycrash_macho_getCommandByTypeFromHeader(
            (const mach_header_t *)header, LC_DYSYMTAB);
    const segment_command_t *linkedit_segment
        = sentrycrash_macho_getSegmentByNameFromHeader((mach_header_t *)header, SEG_LINKEDIT);

    if (symtab_cmd == NULL || dysymtab_cmd == NULL || linkedit_segment == NULL) {
        SENTRY_ASYNC_SAFE_LOG_WARN("Required commands or segments not found");
        return;
    }

    // Find base symbol/string table addresses
    uintptr_t linkedit_base
        = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);

    // Get indirect symbol table (array of uint32_t indices into symbol table)
    uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);

    process_segment(
        header, slide, SEG_DATA, symtab, strtab, indirect_symtab, is_swapping_cxa_throw);
    process_segment(
        header, slide, SEG_DATA_CONST, symtab, strtab, indirect_symtab, is_swapping_cxa_throw);
}

typedef void (*dyld_image_callback)(const struct mach_header *mh, intptr_t vmaddr_slide);
static void
rebind_symbols_for_image_wrapper(const struct mach_header *mh, intptr_t vmaddr_slide)
{
    rebind_symbols_for_image(mh, vmaddr_slide, true);
}

int
sentrycrashct_swap_cxa_throw(const cxa_throw_type handler)
{
    if (handler == NULL) {
        SENTRY_ASYNC_SAFE_LOG_WARN("Handler is NULL, not swapping __cxa_throw");
        return -1;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE("Swapping __cxa_throw.");

    if (g_cxa_originals == NULL) {
        g_cxa_originals_count = 0;
        g_cxa_originals_capacity = 25;
        g_cxa_originals = (SentryCrashImageToOriginalCxaThrowPair *)malloc(
            sizeof(SentryCrashImageToOriginalCxaThrowPair) * g_cxa_originals_capacity);
        if (g_cxa_originals == NULL) {
            SENTRY_ASYNC_SAFE_LOG_ERROR(
                "Failed to allocate memory for g_cxa_originals: %s", strerror(errno));
            return -1;
        }
    }

    if (g_cxa_throw_handler == NULL) {
        g_cxa_throw_handler = handler;
        _dyld_register_func_for_add_image(rebind_symbols_for_image_wrapper);
    } else {
        g_cxa_throw_handler = handler;

        // Call _dyld_image_count inside the loop in case images get loaded or unloaded while
        // iterating.
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const struct mach_header *header = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);

            if (header == NULL || slide == 0) {
                continue;
            }

            rebind_symbols_for_image(
                _dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i), true);
        }
    }
    return 0;
}

int
sentrycrashct_unswap_cxa_throw(void)
{
    if (g_cxa_throw_handler == NULL || g_cxa_originals == NULL || g_cxa_originals_count == 0) {
        SENTRY_ASYNC_SAFE_LOG_INFO("No original __cxa_throw handlers to restore");
        return -1;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE("Unswapping __cxa_throw handler");

    // Call _dyld_image_count inside the loop in case images get loaded or unloaded while
    // iterating.
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);

        if (header == NULL || slide == 0) {
            continue;
        }

        rebind_symbols_for_image(header, slide, false);
    }

    // We MUST NOT clear the pairs because if we can't unswap one of the cxa_throw handlers, we
    // still MUST call the original cxa_throw handler.
    g_cxa_throw_handler = NULL;

    return 0;
}

bool
sentrycrashct_is_cxa_throw_swapped(void)
{
    return g_cxa_throw_handler != NULL;
}
