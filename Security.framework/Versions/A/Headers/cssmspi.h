/*
 * Copyright (c) 1999-2001,2003-2004,2011-2012,2014 Apple Inc. All Rights Reserved.
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
 * cssmspi.h -- Service Provider Interface for CSSM Modules
 */

#ifndef _CSSMSPI_H_
#define _CSSMSPI_H_  1

#include <Security/cssmtype.h>

#ifdef __cplusplus
extern "C" {
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef CSSM_RETURN (CSSMAPI *CSSM_SPI_ModuleEventHandler)
    (const CSSM_GUID *ModuleGuid,
     void *CssmNotifyCallbackCtx,
     uint32 SubserviceId,
     CSSM_SERVICE_TYPE ServiceType,
     CSSM_MODULE_EVENT EventType);

typedef uint32 CSSM_CONTEXT_EVENT;
enum {
    CSSM_CONTEXT_EVENT_CREATE = 1,
    CSSM_CONTEXT_EVENT_DELETE = 2,
    CSSM_CONTEXT_EVENT_UPDATE = 3
};

typedef struct cssm_module_funcs {
    CSSM_SERVICE_TYPE ServiceType;
    uint32 NumberOfServiceFuncs;
    const CSSM_PROC_ADDR *ServiceFuncs;
} CSSM_MODULE_FUNCS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_MODULE_FUNCS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef void *(CSSMAPI *CSSM_UPCALLS_MALLOC)
    (CSSM_HANDLE AddInHandle,
     size_t size) DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef void (CSSMAPI *CSSM_UPCALLS_FREE)
    (CSSM_HANDLE AddInHandle,
     void *memblock) DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef void *(CSSMAPI *CSSM_UPCALLS_REALLOC)
    (CSSM_HANDLE AddInHandle,
     void *memblock,
     size_t size) DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef void *(CSSMAPI *CSSM_UPCALLS_CALLOC)
    (CSSM_HANDLE AddInHandle,
     size_t num,
     size_t size) DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_upcalls {
    CSSM_UPCALLS_MALLOC malloc_func;
    CSSM_UPCALLS_FREE free_func;
    CSSM_UPCALLS_REALLOC realloc_func;
    CSSM_UPCALLS_CALLOC calloc_func;
    CSSM_RETURN (CSSMAPI *CcToHandle_func)
        (CSSM_CC_HANDLE Cc,
         CSSM_MODULE_HANDLE_PTR ModuleHandle);
    CSSM_RETURN (CSSMAPI *GetModuleInfo_func)
        (CSSM_MODULE_HANDLE Module,
         CSSM_GUID_PTR Guid,
         CSSM_VERSION_PTR Version,
         uint32 *SubServiceId,
         CSSM_SERVICE_TYPE *SubServiceType,
         CSSM_ATTACH_FLAGS *AttachFlags,
         CSSM_KEY_HIERARCHY *KeyHierarchy,
         CSSM_API_MEMORY_FUNCS_PTR AttachedMemFuncs,
         CSSM_FUNC_NAME_ADDR_PTR FunctionTable,
         uint32 NumFunctions);
} CSSM_UPCALLS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_UPCALLS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CSSM_RETURN CSSMSPI
CSSM_SPI_ModuleLoad (const CSSM_GUID *CssmGuid,
                     const CSSM_GUID *ModuleGuid,
                     CSSM_SPI_ModuleEventHandler CssmNotifyCallback,
                     void *CssmNotifyCallbackCtx)
					DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CSSM_RETURN CSSMSPI
CSSM_SPI_ModuleUnload (const CSSM_GUID *CssmGuid,
                       const CSSM_GUID *ModuleGuid,
                       CSSM_SPI_ModuleEventHandler CssmNotifyCallback,
                       void *CssmNotifyCallbackCtx)
					DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CSSM_RETURN CSSMSPI
CSSM_SPI_ModuleAttach (const CSSM_GUID *ModuleGuid,
                       const CSSM_VERSION *Version,
                       uint32 SubserviceID,
                       CSSM_SERVICE_TYPE SubServiceType,
                       CSSM_ATTACH_FLAGS AttachFlags,
                       CSSM_MODULE_HANDLE ModuleHandle,
                       CSSM_KEY_HIERARCHY KeyHierarchy,
                       const CSSM_GUID *CssmGuid,
                       const CSSM_GUID *ModuleManagerGuid,
                       const CSSM_GUID *CallerGuid,
                       const CSSM_UPCALLS *Upcalls,
                       CSSM_MODULE_FUNCS_PTR *FuncTbl)
					DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CSSM_RETURN CSSMSPI
CSSM_SPI_ModuleDetach (CSSM_MODULE_HANDLE ModuleHandle)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#pragma clang diagnostic pop

#ifdef __cplusplus
}
#endif

#endif /* _CSSMSPI_H_ */
