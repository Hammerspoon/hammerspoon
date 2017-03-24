/*
 * Copyright (c) 1999-2001,2004,2011,2014 Apple Inc. All Rights Reserved.
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
 * cssmkrspi.h -- Service Provider Interface for Key Recovery Modules
 */

#ifndef _CSSMKRSPI_H_
#define _CSSMKRSPI_H_  1

#include <Security/cssmtype.h>

#ifdef __cplusplus
extern "C" {
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

/* Data types for Key Recovery SPI */

typedef struct cssm_spi_kr_funcs {
    CSSM_RETURN (CSSMKRI *RegistrationRequest)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_CC_HANDLE KRRegistrationContextHandle,
         const CSSM_CONTEXT *KRRegistrationContext,
         const CSSM_DATA *KRInData,
         const CSSM_ACCESS_CREDENTIALS *AccessCredentials,
         CSSM_KR_POLICY_FLAGS KRFlags,
         sint32 *EstimatedTime,
         CSSM_HANDLE_PTR ReferenceHandle);
    CSSM_RETURN (CSSMKRI *RegistrationRetrieve)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_HANDLE ReferenceHandle,
         sint32 *EstimatedTime,
         CSSM_KR_PROFILE_PTR KRProfile);
    CSSM_RETURN (CSSMKRI *GenerateRecoveryFields)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_CC_HANDLE KREnablementContextHandle,
         const CSSM_CONTEXT *KREnablementContext,
         CSSM_CC_HANDLE CryptoContextHandle,
         const CSSM_CONTEXT *CryptoContext,
         const CSSM_DATA *KRSPOptions,
         CSSM_KR_POLICY_FLAGS KRFlags,
         CSSM_DATA_PTR KRFields);
    CSSM_RETURN (CSSMKRI *ProcessRecoveryFields)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_CC_HANDLE KREnablementContextHandle,
         const CSSM_CONTEXT *KREnablementContext,
         CSSM_CC_HANDLE CryptoContextHandle,
         const CSSM_CONTEXT *CryptoContext,
         const CSSM_DATA *KRSPOptions,
         CSSM_KR_POLICY_FLAGS KRFlags,
         const CSSM_DATA *KRFields);
    CSSM_RETURN (CSSMKRI *RecoveryRequest)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_CC_HANDLE KRRequestContextHandle,
         const CSSM_CONTEXT *KRRequestContext,
         const CSSM_DATA *KRInData,
         const CSSM_ACCESS_CREDENTIALS *AccessCredentials,
         sint32 *EstimatedTime,
         CSSM_HANDLE_PTR ReferenceHandle);
    CSSM_RETURN (CSSMKRI *RecoveryRetrieve)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_HANDLE ReferenceHandle,
         sint32 *EstimatedTime,
         CSSM_HANDLE_PTR CacheHandle,
         uint32 *NumberOfRecoveredKeys);
    CSSM_RETURN (CSSMKRI *GetRecoveredObject)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_HANDLE CacheHandle,
         uint32 IndexInResults,
         CSSM_CSP_HANDLE CSPHandle,
         const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
         uint32 Flags,
         CSSM_KEY_PTR RecoveredKey,
         CSSM_DATA_PTR OtherInfo);
    CSSM_RETURN (CSSMKRI *RecoveryRequestAbort)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_HANDLE ResultsHandle);
    CSSM_RETURN (CSSMKRI *PassThrough)
        (CSSM_KRSP_HANDLE KRSPHandle,
         CSSM_CC_HANDLE KeyRecoveryContextHandle,
         const CSSM_CONTEXT *KeyRecoveryContext,
         CSSM_CC_HANDLE CryptoContextHandle,
         const CSSM_CONTEXT *CryptoContext,
         uint32 PassThroughId,
         const void *InputParams,
         void **OutputParams);
} CSSM_SPI_KR_FUNCS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_SPI_KR_FUNCS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#pragma clang diagnostic pop

#ifdef __cplusplus
}
#endif

#endif /* _CSSMKRSPI_H_ */
