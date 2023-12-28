// clang-format off
/*
 * Copyright (C) 2006-2019 Apple Inc. All rights reserved.
 * Copyright (C) 2007-2009 Torch Mobile, Inc.
 * Copyright (C) 2010, 2011 Research In Motion Limited. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Obtained from: https://github.com/WebKit/WebKit/blob/main/Source/WTF/wtf/PlatformCPU.h
 */

#pragma once

#include "SentryCompiler.h"

/* ==== Platform adaptation macros: these describe properties of the target environment. ==== */

/* CPU() - the target CPU architecture */
#define CPU(SENTRY_FEATURE) (defined SENTRY_CPU_##SENTRY_FEATURE  && SENTRY_CPU_##SENTRY_FEATURE)

/* ==== CPU() - the target CPU architecture ==== */
/* CPU(KNOWN) becomes true if we explicitly support a target CPU. */

/* CPU(MIPS) - MIPS 32-bit and 64-bit */
#if (defined(mips) || defined(__mips__) || defined(MIPS) || defined(_MIPS_) || defined(__mips64))
#if defined(_ABI64) && (_MIPS_SIM == _ABI64)
#define SENTRY_CPU_MIPS64 1
#define SENTRY_MIPS_ARCH __mips64
#else
#define SENTRY_CPU_MIPS 1
#define SENTRY_MIPS_ARCH __mips
#endif
#define SENTRY_CPU_KNOWN 1
#define SENTRY_MIPS_PIC (defined __PIC__)
#define SENTRY_MIPS_ISA(v) (defined SENTRY_MIPS_ARCH && SENTRY_MIPS_ARCH == v)
#define SENTRY_MIPS_ISA_AT_LEAST(v) (defined SENTRY_MIPS_ARCH && SENTRY_MIPS_ARCH >= v)
#define SENTRY_MIPS_ARCH_REV __mips_isa_rev
#define SENTRY_MIPS_ISA_REV(v) (defined SENTRY_MIPS_ARCH_REV && SENTRY_MIPS_ARCH_REV == v)
#define SENTRY_MIPS_ISA_REV_AT_LEAST(v) (defined SENTRY_MIPS_ARCH_REV && SENTRY_MIPS_ARCH_REV >= v)
#define SENTRY_MIPS_DOUBLE_FLOAT (defined __mips_hard_float && !defined __mips_single_float)
#define SENTRY_MIPS_FP64 (defined __mips_fpr && __mips_fpr == 64)
/* MIPS requires allocators to use aligned memory */
#define USE_ARENA_ALLOC_ALIGNMENT_INTEGER 1
#endif /* MIPS */

/* CPU(PPC64) - PowerPC 64-bit Big Endian */
#if (  defined(__ppc64__)      \
    || defined(__PPC64__))     \
    && defined(__BYTE_ORDER__) \
    && (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
#define SENTRY_CPU_PPC64 1
#define SENTRY_CPU_KNOWN 1
#endif

/* CPU(PPC64LE) - PowerPC 64-bit Little Endian */
#if (   defined(__ppc64__)     \
    || defined(__PPC64__)      \
    || defined(__ppc64le__)    \
    || defined(__PPC64LE__))   \
    && defined(__BYTE_ORDER__) \
    && (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#define SENTRY_CPU_PPC64LE 1
#define SENTRY_CPU_KNOWN 1
#endif

/* CPU(PPC) - PowerPC 32-bit */
#if (  defined(__ppc__)        \
    || defined(__PPC__)        \
    || defined(__powerpc__)    \
    || defined(__powerpc)      \
    || defined(__POWERPC__)    \
    || defined(_M_PPC)         \
    || defined(__PPC))         \
    && !CPU(PPC64)             \
    && CPU(BIG_ENDIAN)
#define SENTRY_CPU_PPC 1
#define SENTRY_CPU_KNOWN 1
#endif

/* CPU(X86) - i386 / x86 32-bit */
#if   defined(__i386__) \
    || defined(i386)     \
    || defined(_M_IX86)  \
    || defined(_X86_)    \
    || defined(__THW_INTEL)
#define SENTRY_CPU_X86 1
#define SENTRY_CPU_KNOWN 1

#if defined(__SSE2__) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
#define SENTRY_CPU_X86_SSE2 1
#endif

#endif

/* CPU(X86_64) - AMD64 / Intel64 / x86_64 64-bit */
#if   defined(__x86_64__) \
    || defined(_M_X64)
#define SENTRY_CPU_X86_64 1
#define SENTRY_CPU_X86_SSE2 1
#define SENTRY_CPU_KNOWN 1
#endif

/* CPU(ARM64) - Apple */
#if defined(__arm64__) || defined(__aarch64__)
#define SENTRY_CPU_ARM64 1
#define SENTRY_CPU_KNOWN 1

#if defined(__arm64e__)
#define SENTRY_CPU_ARM64E 1
#endif
#endif

/* CPU(ARM) - ARM, any version*/
#define SENTRY_ARM_ARCH_AT_LEAST(N) (CPU(ARM) && SENTRY_ARM_ARCH_VERSION >= N)

#if   defined(arm) \
    || defined(__arm__) \
    || defined(ARM) \
    || defined(_ARM_)
#define SENTRY_CPU_ARM 1
#define SENTRY_CPU_KNOWN 1

#if defined(__ARM_PCS_VFP)
#define SENTRY_CPU_ARM_HARDFP 1
#endif

/* Set SENTRY_ARM_ARCH_VERSION */
#if   defined(__ARM_ARCH_4__) \
    || defined(__ARM_ARCH_4T__) \
    || defined(__MARM_ARMV4__)
#define SENTRY_ARM_ARCH_VERSION 4

#elif defined(__ARM_ARCH_5__) \
    || defined(__ARM_ARCH_5T__) \
    || defined(__MARM_ARMV5__)
#define SENTRY_ARM_ARCH_VERSION 5

#elif defined(__ARM_ARCH_5E__) \
    || defined(__ARM_ARCH_5TE__) \
    || defined(__ARM_ARCH_5TEJ__)
#define SENTRY_ARM_ARCH_VERSION 5
/*ARMv5TE requires allocators to use aligned memory*/
#define USE_ARENA_ALLOC_ALIGNMENT_INTEGER 1

#elif defined(__ARM_ARCH_6__) \
    || defined(__ARM_ARCH_6J__) \
    || defined(__ARM_ARCH_6K__) \
    || defined(__ARM_ARCH_6Z__) \
    || defined(__ARM_ARCH_6ZK__) \
    || defined(__ARM_ARCH_6T2__) \
    || defined(__ARMV6__)
#define SENTRY_ARM_ARCH_VERSION 6

#elif defined(__ARM_ARCH_7A__) \
    || defined(__ARM_ARCH_7K__) \
    || defined(__ARM_ARCH_7R__) \
    || defined(__ARM_ARCH_7S__)
#define SENTRY_ARM_ARCH_VERSION 7

#elif defined(__ARM_ARCH_8__) \
    || defined(__ARM_ARCH_8A__)
#define SENTRY_ARM_ARCH_VERSION 8

/* MSVC sets _M_ARM */
#elif defined(_M_ARM)
#define SENTRY_ARM_ARCH_VERSION _M_ARM

/* RVCT sets _TARGET_ARCH_ARM */
#elif defined(__TARGET_ARCH_ARM)
#define SENTRY_ARM_ARCH_VERSION __TARGET_ARCH_ARM

#if defined(__TARGET_ARCH_5E) \
    || defined(__TARGET_ARCH_5TE) \
    || defined(__TARGET_ARCH_5TEJ)
/*ARMv5TE requires allocators to use aligned memory*/
#define USE_ARENA_ALLOC_ALIGNMENT_INTEGER 1
#endif

#else
#define SENTRY_ARM_ARCH_VERSION 0

#endif

/* Set SENTRY_THUMB_ARCH_VERSION */
#if   defined(__ARM_ARCH_4T__)
#define SENTRY_THUMB_ARCH_VERSION 1

#elif defined(__ARM_ARCH_5T__) \
    || defined(__ARM_ARCH_5TE__) \
    || defined(__ARM_ARCH_5TEJ__)
#define SENTRY_THUMB_ARCH_VERSION 2

#elif defined(__ARM_ARCH_6J__) \
    || defined(__ARM_ARCH_6K__) \
    || defined(__ARM_ARCH_6Z__) \
    || defined(__ARM_ARCH_6ZK__) \
    || defined(__ARM_ARCH_6M__)
#define SENTRY_THUMB_ARCH_VERSION 3

#elif defined(__ARM_ARCH_6T2__) \
    || defined(__ARM_ARCH_7__) \
    || defined(__ARM_ARCH_7A__) \
    || defined(__ARM_ARCH_7K__) \
    || defined(__ARM_ARCH_7M__) \
    || defined(__ARM_ARCH_7R__) \
    || defined(__ARM_ARCH_7S__)
#define SENTRY_THUMB_ARCH_VERSION 4

/* RVCT sets __TARGET_ARCH_THUMB */
#elif defined(__TARGET_ARCH_THUMB)
#define SENTRY_THUMB_ARCH_VERSION __TARGET_ARCH_THUMB

#else
#define SENTRY_THUMB_ARCH_VERSION 0
#endif


/* CPU(ARMV5_OR_LOWER) - ARM instruction set v5 or earlier */
/* On ARMv5 and below the natural alignment is required.
   And there are some other differences for v5 or earlier. */
#if !defined(ARMV5_OR_LOWER) && !SENTRY_ARM_ARCH_AT_LEAST(6)
#define SENTRY_CPU_ARMV5_OR_LOWER 1
#endif


/* CPU(ARM_TRADITIONAL) - Thumb2 is not available, only traditional ARM (v4 or greater) */
/* CPU(ARM_THUMB2) - Thumb2 instruction set is available */
/* Only one of these will be defined. */
#if !defined(SENTRY_CPU_ARM_TRADITIONAL) && !defined(SENTRY_CPU_ARM_THUMB2)
#  if defined(thumb2) || defined(__thumb2__) \
    || ((defined(__thumb) || defined(__thumb__)) && SENTRY_THUMB_ARCH_VERSION == 4)
#    define SENTRY_CPU_ARM_TRADITIONAL 0
#    define SENTRY_CPU_ARM_THUMB2 1
#  elif SENTRY_ARM_ARCH_AT_LEAST(4)
#    define SENTRY_CPU_ARM_TRADITIONAL 1
#    define SENTRY_CPU_ARM_THUMB2 0
#  else
#    error "Not supported ARM architecture"
#  endif
#elif CPU(ARM_TRADITIONAL) && CPU(ARM_THUMB2) /* Sanity Check */
#  error "Cannot use both of SENTRY_CPU_ARM_TRADITIONAL and SENTRY_CPU_ARM_THUMB2 platforms"
#endif /* !defined(SENTRY_CPU_ARM_TRADITIONAL) && !defined(SENTRY_CPU_ARM_THUMB2) */

#if defined(__ARM_NEON__) && !defined(SENTRY_CPU_ARM_NEON)
#define SENTRY_CPU_ARM_NEON 1
#endif

#if CPU(ARM_NEON)
/* All NEON intrinsics usage can be disabled by this macro. */
#define HAVE_ARM_NEON_INTRINSICS 1
#endif

#if (defined(__VFP_FP__) && !defined(__SOFTFP__))
#define SENTRY_CPU_ARM_VFP 1
#endif

/* If CPU(ARM_NEON) is not enabled, we'll conservatively assume only VFP2 or VFPv3D16
   support is available. Hence, only the first 16 64-bit floating point registers
   are available. See:
   NEON registers: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0473c/CJACABEJ.html
   VFP2 and VFP3 registers: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0473c/CIHDIBDG.html
   NEON to VFP register mapping: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0473c/CJAIJHFC.html
*/
#if CPU(ARM_NEON)
#define SENTRY_CPU_ARM_VFP_V3_D32 1
#else
#define SENTRY_CPU_ARM_VFP_V2 1
#endif

#if defined(__ARM_ARCH_7K__)
#define SENTRY_CPU_APPLE_ARMV7K 1
#endif

#if defined(__ARM_ARCH_7S__)
#define SENTRY_CPU_APPLE_ARMV7S 1
#endif

#if defined(__ARM_ARCH_EXT_IDIV__) || CPU(APPLE_ARMV7S)
#define HAVE_ARM_IDIV_INSTRUCTIONS 1
#endif

#endif /* ARM */

#if !CPU(KNOWN)
#define SENTRY_CPU_UNKNOWN 1
#endif

#if CPU(ARM) || CPU(MIPS) || CPU(UNKNOWN)
#define SENTRY_CPU_NEEDS_ALIGNED_ACCESS 1
#endif

#if COMPILER(GCC_COMPATIBLE)
/* __LP64__ is not defined on 64bit Windows since it uses LLP64. Using __SIZEOF_POINTER__ is simpler. */
#if __SIZEOF_POINTER__ == 8
#define SENTRY_CPU_ADDRESS64 1
#elif __SIZEOF_POINTER__ == 4
#define SENTRY_CPU_ADDRESS32 1
#else
#error "Unsupported pointer width"
#endif
#elif COMPILER(MSVC)
#if defined(_WIN64)
#define SENTRY_CPU_ADDRESS64 1
#else
#define SENTRY_CPU_ADDRESS32 1
#endif
#else
/* This is the most generic way. But in OS(DARWIN), Platform.h can be included by sandbox definition file (.sb).
 * At that time, we cannot include "stdint.h" header. So in the case of known compilers, we use predefined constants instead. */
#include <stdint.h>
#if UINTPTR_MAX > UINT32_MAX
#define SENTRY_CPU_ADDRESS64 1
#else
#define SENTRY_CPU_ADDRESS32 1
#endif
#endif
