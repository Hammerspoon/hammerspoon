/*
 * Copyright (c) 2000-2001,2003-2004,2007,2011-2012 Apple Inc. All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 *
 * cssmconfig.h -- Platform specific defines and typedefs for cdsa.
 */

#ifndef _CSSMCONFIG_H_
#define _CSSMCONFIG_H_  1

#include <AvailabilityMacros.h>
#include <TargetConditionals.h>
#include <ConditionalMacros.h>


/* #if defined(TARGET_API_MAC_OS8) || defined(TARGET_API_MAC_CARBON) || defined(TARGET_API_MAC_OSX) */
#if defined(TARGET_OS_MAC)
#include <sys/types.h>
#include <stdint.h>
#else
#error Unknown API architecture.
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _SINT64
typedef int64_t sint64;
#define _SINT64
#endif
#ifndef _UINT64
typedef uint64_t uint64;
#define _UINT64
#endif
#ifndef _SINT32
typedef int32_t sint32;
#define _SINT32
#endif
#ifndef _SINT16
typedef int16_t sint16;
#define _SINT16
#endif
#ifndef _SINT8
typedef int8_t sint8;
#define _SINT8
#endif
#ifndef _UINT32
typedef uint32_t uint32;
#define _UINT32
#endif
#ifndef _UINT16
typedef uint16_t uint16;
#define _UINT16
#endif
#ifndef _UINT8
typedef uint8_t uint8;
#define _UINT8
#endif

typedef intptr_t CSSM_INTPTR;
typedef size_t CSSM_SIZE;

#define CSSMACI
#define CSSMAPI
#define CSSMCLI
#define CSSMCSPI
#define CSSMDLI
#define CSSMKRI
#define CSSMSPI
#define CSSMTPI

#ifdef __cplusplus
}
#endif

#endif /* _CSSMCONFIG_H_ */
