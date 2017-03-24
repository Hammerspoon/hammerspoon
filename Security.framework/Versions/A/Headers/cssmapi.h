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
 * cssmapi.h -- Application Programmers Interfaces for CSSM
 */

#ifndef _CSSMAPI_H_
#define _CSSMAPI_H_  1

#include <Security/cssmtype.h>

/* ==========================================================================
	W A R N I N G : CDSA has been deprecated starting with 10.7.  While the
	APIs will continue to work, developers should update their code to use
	the APIs that are suggested and NOT use the CDSA APIs
   ========================================================================== */

#ifdef __cplusplus
extern "C" {
#endif

/* Core Functions */

/* --------------------------------------------------------------------------
	CSSM_Init has been deprecated in 10.7 and later.  There is no alternate
	API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_Init (const CSSM_VERSION *Version,
           CSSM_PRIVILEGE_SCOPE Scope,
           const CSSM_GUID *CallerGuid,
           CSSM_KEY_HIERARCHY KeyHierarchy,
           CSSM_PVC_MODE *PvcPolicy,
           const void *Reserved)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_Terminate has been deprecated in 10.7 and later.  There is no alternate
	API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_Terminate (void)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_ModuleLoad has been deprecated in 10.7 and later.  There is no 
	alternate API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_ModuleLoad (const CSSM_GUID *ModuleGuid,
                 CSSM_KEY_HIERARCHY KeyHierarchy,
                 CSSM_API_ModuleEventHandler AppNotifyCallback,
                 void *AppNotifyCallbackCtx)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_ModuleUnload has been deprecated in 10.7 and later.  There is no 
	alternate API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_ModuleUnload (const CSSM_GUID *ModuleGuid,
                   CSSM_API_ModuleEventHandler AppNotifyCallback,
                   void *AppNotifyCallbackCtx)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_Introduce has been deprecated in 10.7 and later.  There is no 
	alternate API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_Introduce (const CSSM_GUID *ModuleID,
                CSSM_KEY_HIERARCHY KeyHierarchy)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_Unintroduce has been deprecated in 10.7 and later.  There is no 
	alternate API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_Unintroduce (const CSSM_GUID *ModuleID)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_ModuleAttach has been deprecated in 10.7 and later.  There is no 
	alternate API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_ModuleAttach (const CSSM_GUID *ModuleGuid,
                   const CSSM_VERSION *Version,
                   const CSSM_API_MEMORY_FUNCS *MemoryFuncs,
                   uint32 SubserviceID,
                   CSSM_SERVICE_TYPE SubServiceType,
                   CSSM_ATTACH_FLAGS AttachFlags,
                   CSSM_KEY_HIERARCHY KeyHierarchy,
                   CSSM_FUNC_NAME_ADDR *FunctionTable,
                   uint32 NumFunctionTable,
                   const void *Reserved,
                   CSSM_MODULE_HANDLE_PTR NewModuleHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_ModuleDetach has been deprecated in 10.7 and later.  There is no 
	alternate API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_ModuleDetach (CSSM_MODULE_HANDLE ModuleHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_SetPrivilege has been deprecated in 10.7 and later.  There is no alternate
	API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_SetPrivilege (CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetPrivilege has been deprecated in 10.7 and later.  There is no 
	alternate API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetPrivilege (CSSM_PRIVILEGE *Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetModuleGUIDFromHandle has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling CDSA 
	APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetModuleGUIDFromHandle (CSSM_MODULE_HANDLE ModuleHandle,
                              CSSM_GUID_PTR ModuleGUID)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetSubserviceUIDFromHandle has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling CDSA 
	APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetSubserviceUIDFromHandle (CSSM_MODULE_HANDLE ModuleHandle,
                                 CSSM_SUBSERVICE_UID_PTR SubserviceUID)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_ListAttachedModuleManagers has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling CDSA 
	APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_ListAttachedModuleManagers (uint32 *NumberOfModuleManagers,
                                 CSSM_GUID_PTR ModuleManagerGuids)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetAPIMemoryFunctions has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling CDSA 
	APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetAPIMemoryFunctions (CSSM_MODULE_HANDLE AddInHandle,
                            CSSM_API_MEMORY_FUNCS_PTR AppMemoryFuncs)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Cryptographic Context Operations */

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateSignatureContext has been deprecated in 10.7 and later.  
	The replacement API for this is SecSignTransformCreate in the 
	SecSignVerifyTransform.h file.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateSignatureContext (CSSM_CSP_HANDLE CSPHandle,
                                 CSSM_ALGORITHMS AlgorithmID,
                                 const CSSM_ACCESS_CREDENTIALS *AccessCred,
                                 const CSSM_KEY *Key,
                                 CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateSignatureContext has been deprecated in 10.7 and later.  
	The replacement API for this is SecSignTransformCreate in the 
	SecSignVerifyTransform.h file.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateSymmetricContext (CSSM_CSP_HANDLE CSPHandle,
                                 CSSM_ALGORITHMS AlgorithmID,
                                 CSSM_ENCRYPT_MODE Mode,
                                 const CSSM_ACCESS_CREDENTIALS *AccessCred,
                                 const CSSM_KEY *Key,
                                 const CSSM_DATA *InitVector,
                                 CSSM_PADDING Padding,
                                 void *Reserved,
                                 CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateDigestContext has been deprecated in 10.7 and later.  
	The replacement API for this is SecDigestTransformCreate in the 
	SecDigestTransform.h file.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateDigestContext (CSSM_CSP_HANDLE CSPHandle,
                              CSSM_ALGORITHMS AlgorithmID,
                              CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateMacContext has been deprecated in 10.7 and later.  
	The replacement API for this is SecDigestTransformCreate in the 
	SecDigestTransform.h file.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateMacContext (CSSM_CSP_HANDLE CSPHandle,
                           CSSM_ALGORITHMS AlgorithmID,
                           const CSSM_KEY *Key,
                           CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateRandomGenContext has been deprecated in 10.7 and later.  
	There is no replacement API as this API is only needed with CDSA.  Please
	see the SecRandom.h file to get random numbers
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateRandomGenContext (CSSM_CSP_HANDLE CSPHandle,
                                 CSSM_ALGORITHMS AlgorithmID,
                                 const CSSM_CRYPTO_DATA *Seed,
                                 CSSM_SIZE Length,
                                 CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateAsymmetricContext has been deprecated in 10.7 and later.  
	There is no direct replacement of this API as it is only needed by CDSA.
	For asymmertical encryption/decryption use the SecEncryptTransformCreate
	or SecDecryptTransformCreate with a asymmertical key.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateAsymmetricContext (CSSM_CSP_HANDLE CSPHandle,
                                  CSSM_ALGORITHMS AlgorithmID,
                                  const CSSM_ACCESS_CREDENTIALS *AccessCred,
                                  const CSSM_KEY *Key,
                                  CSSM_PADDING Padding,
                                  CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateDeriveKeyContext has been deprecated in 10.7 and later.  
	The replacement for this API would be the SecKeyDeriveFromPassword API
	in the SecKey.h file
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateDeriveKeyContext (CSSM_CSP_HANDLE CSPHandle,
                                 CSSM_ALGORITHMS AlgorithmID,
                                 CSSM_KEY_TYPE DeriveKeyType,
                                 uint32 DeriveKeyLengthInBits,
                                 const CSSM_ACCESS_CREDENTIALS *AccessCred,
                                 const CSSM_KEY *BaseKey,
                                 uint32 IterationCount,
                                 const CSSM_DATA *Salt,
                                 const CSSM_CRYPTO_DATA *Seed,
                                 CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreateKeyGenContext has been deprecated in 10.7 and later.  
	The replacement for this API would be either the SecKeyGeneratePair API
	or the SecKeyGenerateSymmetric API in the SecKey.h file
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreateKeyGenContext (CSSM_CSP_HANDLE CSPHandle,
                              CSSM_ALGORITHMS AlgorithmID,
                              uint32 KeySizeInBits,
                              const CSSM_CRYPTO_DATA *Seed,
                              const CSSM_DATA *Salt,
                              const CSSM_DATE *StartDate,
                              const CSSM_DATE *EndDate,
                              const CSSM_DATA *Params,
                              CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_CreatePassThroughContext has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_CreatePassThroughContext (CSSM_CSP_HANDLE CSPHandle,
                                   const CSSM_KEY *Key,
                                   CSSM_CC_HANDLE *NewContextHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetContext has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetContext (CSSM_CC_HANDLE CCHandle,
                 CSSM_CONTEXT_PTR *Context)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_FreeContext has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_FreeContext (CSSM_CONTEXT_PTR Context)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_SetContext has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_SetContext (CSSM_CC_HANDLE CCHandle,
                 const CSSM_CONTEXT *Context)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DeleteContext has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DeleteContext (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetContextAttribute has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetContextAttribute (const CSSM_CONTEXT *Context,
                          uint32 AttributeType,
                          CSSM_CONTEXT_ATTRIBUTE_PTR *ContextAttribute)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_UpdateContextAttributes has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_UpdateContextAttributes (CSSM_CC_HANDLE CCHandle,
                              uint32 NumberOfAttributes,
                              const CSSM_CONTEXT_ATTRIBUTE *ContextAttributes)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DeleteContextAttributes has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DeleteContextAttributes (CSSM_CC_HANDLE CCHandle,
                              uint32 NumberOfAttributes,
                              const CSSM_CONTEXT_ATTRIBUTE *ContextAttributes)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Cryptographic Sessions and Controlled Access to Keys */
/* --------------------------------------------------------------------------
	CSSM_CSP_Login has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_Login (CSSM_CSP_HANDLE CSPHandle,
                const CSSM_ACCESS_CREDENTIALS *AccessCred,
                const CSSM_DATA *LoginName,
                const void *Reserved)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_Logout has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_Logout (CSSM_CSP_HANDLE CSPHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_GetLoginAcl has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_GetLoginAcl (CSSM_CSP_HANDLE CSPHandle,
                      const CSSM_STRING *SelectionTag,
                      uint32 *NumberOfAclInfos,
                      CSSM_ACL_ENTRY_INFO_PTR *AclInfos)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_ChangeLoginAcl has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_ChangeLoginAcl (CSSM_CSP_HANDLE CSPHandle,
                         const CSSM_ACCESS_CREDENTIALS *AccessCred,
                         const CSSM_ACL_EDIT *AclEdit)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetKeyAcl has been deprecated in 10.7 and later.  
	If the key in question is in a keychain then the ACL for the key can be 
	aquired by using the SecItemCopyMatching API specifically 
	kSecReturnAttributes with a value of kCFBooleanTrue.  In the attributes
	dictionary is kSecAttrAccess key with a value of a SecAccessRef. With
	a SecAccessRef the ACL for the key can be gotten using either the
	SecAccessCopyACLList API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetKeyAcl (CSSM_CSP_HANDLE CSPHandle,
                const CSSM_KEY *Key,
                const CSSM_STRING *SelectionTag,
                uint32 *NumberOfAclInfos,
                CSSM_ACL_ENTRY_INFO_PTR *AclInfos)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_ChangeKeyAcl has been deprecated in 10.7 and later.  
	If the key in question is in a keychain then the ACL for the key can be 
	changed by using the SecItemUpdate API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_ChangeKeyAcl (CSSM_CSP_HANDLE CSPHandle,
                   const CSSM_ACCESS_CREDENTIALS *AccessCred,
                   const CSSM_ACL_EDIT *AclEdit,
                   const CSSM_KEY *Key)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GetKeyOwner has been deprecated in 10.7 and later.  
	If the key in question is in a keychain then the ACL for the key can be 
	aquired by using the SecItemCopyMatching API specifically 
	kSecReturnAttributes with a value of kCFBooleanTrue.  In the attributes
	dictionary is kSecAttrAccess key with a value of a SecAccessRef. With
	a SecAccessRef the ACL for the key can be gotten using either the
	SecAccessCopyOwnerAndACL API.
   -------------------------------------------------------------------------- */

CSSM_RETURN CSSMAPI
CSSM_GetKeyOwner (CSSM_CSP_HANDLE CSPHandle,
                  const CSSM_KEY *Key,
                  CSSM_ACL_OWNER_PROTOTYPE_PTR Owner)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_ChangeKeyOwner has been deprecated in 10.7 and later.  
	If the key in question is in a keychain then the ACL for the key can be 
	changed by using the SecItemUpdate API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_ChangeKeyOwner (CSSM_CSP_HANDLE CSPHandle,
                     const CSSM_ACCESS_CREDENTIALS *AccessCred,
                     const CSSM_KEY *Key,
                     const CSSM_ACL_OWNER_PROTOTYPE *NewOwner)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_GetLoginOwner has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_GetLoginOwner (CSSM_CSP_HANDLE CSPHandle,
                        CSSM_ACL_OWNER_PROTOTYPE_PTR Owner)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_ChangeLoginOwner has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_ChangeLoginOwner (CSSM_CSP_HANDLE CSPHandle,
                           const CSSM_ACCESS_CREDENTIALS *AccessCred,
                           const CSSM_ACL_OWNER_PROTOTYPE *NewOwner)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_SignData has been deprecated in 10.7 and later.  
	To sign data use the SecSignTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_SignData (CSSM_CC_HANDLE CCHandle,
               const CSSM_DATA *DataBufs,
               uint32 DataBufCount,
               CSSM_ALGORITHMS DigestAlgorithm,
               CSSM_DATA_PTR Signature)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_SignDataInit has been deprecated in 10.7 and later.  
	To sign data use the SecSignTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_SignDataInit (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_SignDataUpdate has been deprecated in 10.7 and later.  
	To sign data use the SecSignTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_SignDataUpdate (CSSM_CC_HANDLE CCHandle,
                     const CSSM_DATA *DataBufs,
                     uint32 DataBufCount)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_SignDataFinal has been deprecated in 10.7 and later.  
	To sign data use the SecSignTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_SignDataFinal (CSSM_CC_HANDLE CCHandle,
                    CSSM_DATA_PTR Signature)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyData has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyData (CSSM_CC_HANDLE CCHandle,
                 const CSSM_DATA *DataBufs,
                 uint32 DataBufCount,
                 CSSM_ALGORITHMS DigestAlgorithm,
                 const CSSM_DATA *Signature)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyDataInit has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyDataInit (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyDataUpdate has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyDataUpdate (CSSM_CC_HANDLE CCHandle,
                       const CSSM_DATA *DataBufs,
                       uint32 DataBufCount)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyDataFinal has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyDataFinal (CSSM_CC_HANDLE CCHandle,
                      const CSSM_DATA *Signature)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DigestData has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DigestData (CSSM_CC_HANDLE CCHandle,
                 const CSSM_DATA *DataBufs,
                 uint32 DataBufCount,
                 CSSM_DATA_PTR Digest)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DigestDataInit has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DigestDataInit (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DigestDataUpdate has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DigestDataUpdate (CSSM_CC_HANDLE CCHandle,
                       const CSSM_DATA *DataBufs,
                       uint32 DataBufCount)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DigestDataClone has been deprecated in 10.7 and later.  
	Given that transforms can have be connected into chains, this 
	functionality is no longer needed.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DigestDataClone (CSSM_CC_HANDLE CCHandle,
                      CSSM_CC_HANDLE *ClonednewCCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DigestDataFinal has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DigestDataFinal (CSSM_CC_HANDLE CCHandle,
                      CSSM_DATA_PTR Digest)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateMac has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateMac (CSSM_CC_HANDLE CCHandle,
                  const CSSM_DATA *DataBufs,
                  uint32 DataBufCount,
                  CSSM_DATA_PTR Mac)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateMacInit has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateMacInit (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateMacUpdate has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateMacUpdate (CSSM_CC_HANDLE CCHandle,
                        const CSSM_DATA *DataBufs,
                        uint32 DataBufCount)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateMacFinal has been deprecated in 10.7 and later.  
	To sign data use the SecDigestTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateMacFinal (CSSM_CC_HANDLE CCHandle,
                       CSSM_DATA_PTR Mac)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyMac has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyMac (CSSM_CC_HANDLE CCHandle,
                const CSSM_DATA *DataBufs,
                uint32 DataBufCount,
                const CSSM_DATA *Mac)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyMacInit has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyMacInit (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyMacUpdate has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyMacUpdate (CSSM_CC_HANDLE CCHandle,
                      const CSSM_DATA *DataBufs,
                      uint32 DataBufCount)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyMacFinal has been deprecated in 10.7 and later.  
	To sign data use the SecVerifyTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyMacFinal (CSSM_CC_HANDLE CCHandle,
                     const CSSM_DATA *Mac)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_QuerySize has been deprecated in 10.7 and later.  
	Given that transforms buffer data into queues, this functionality is no
	longer needed.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_QuerySize (CSSM_CC_HANDLE CCHandle,
                CSSM_BOOL Encrypt,
                uint32 QuerySizeCount,
                CSSM_QUERY_SIZE_DATA_PTR DataBlockSizes)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* --------------------------------------------------------------------------
	CSSM_EncryptData has been deprecated in 10.7 and later.  
	To sign data use the SecEncryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_EncryptData (CSSM_CC_HANDLE CCHandle,
                  const CSSM_DATA *ClearBufs,
                  uint32 ClearBufCount,
                  CSSM_DATA_PTR CipherBufs,
                  uint32 CipherBufCount,
                  CSSM_SIZE *bytesEncrypted,
                  CSSM_DATA_PTR RemData)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_EncryptDataP has been deprecated in 10.7 and later.  
	To sign data use the SecEncryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_EncryptDataP (CSSM_CC_HANDLE CCHandle,
                   const CSSM_DATA *ClearBufs,
                   uint32 ClearBufCount,
                   CSSM_DATA_PTR CipherBufs,
                   uint32 CipherBufCount,
                   CSSM_SIZE *bytesEncrypted,
                   CSSM_DATA_PTR RemData,
                   CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_EncryptDataInit has been deprecated in 10.7 and later.  
	To sign data use the SecEncryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_EncryptDataInit (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_EncryptDataInitP has been deprecated in 10.7 and later.  
	To sign data use the SecEncryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_EncryptDataInitP (CSSM_CC_HANDLE CCHandle,
                       CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_EncryptDataUpdate has been deprecated in 10.7 and later.  
	To sign data use the SecEncryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_EncryptDataUpdate (CSSM_CC_HANDLE CCHandle,
                        const CSSM_DATA *ClearBufs,
                        uint32 ClearBufCount,
                        CSSM_DATA_PTR CipherBufs,
                        uint32 CipherBufCount,
                        CSSM_SIZE *bytesEncrypted)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_EncryptDataFinal has been deprecated in 10.7 and later.  
	To sign data use the SecEncryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_EncryptDataFinal (CSSM_CC_HANDLE CCHandle,
                       CSSM_DATA_PTR RemData)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DecryptData has been deprecated in 10.7 and later.  
	To sign data use the SecDecryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DecryptData (CSSM_CC_HANDLE CCHandle,
                  const CSSM_DATA *CipherBufs,
                  uint32 CipherBufCount,
                  CSSM_DATA_PTR ClearBufs,
                  uint32 ClearBufCount,
                  CSSM_SIZE *bytesDecrypted,
                  CSSM_DATA_PTR RemData)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DecryptDataP has been deprecated in 10.7 and later.  
	To sign data use the SecDecryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DecryptDataP (CSSM_CC_HANDLE CCHandle,
                   const CSSM_DATA *CipherBufs,
                   uint32 CipherBufCount,
                   CSSM_DATA_PTR ClearBufs,
                   uint32 ClearBufCount,
                   CSSM_SIZE *bytesDecrypted,
                   CSSM_DATA_PTR RemData,
                   CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DecryptDataInit has been deprecated in 10.7 and later.  
	To sign data use the SecDecryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DecryptDataInit (CSSM_CC_HANDLE CCHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DecryptDataInitP has been deprecated in 10.7 and later.  
	To sign data use the SecDecryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DecryptDataInitP (CSSM_CC_HANDLE CCHandle,
                       CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DecryptDataUpdate has been deprecated in 10.7 and later.  
	To sign data use the SecDecryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DecryptDataUpdate (CSSM_CC_HANDLE CCHandle,
                        const CSSM_DATA *CipherBufs,
                        uint32 CipherBufCount,
                        CSSM_DATA_PTR ClearBufs,
                        uint32 ClearBufCount,
                        CSSM_SIZE *bytesDecrypted)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DecryptDataFinal has been deprecated in 10.7 and later.  
	To sign data use the SecDecryptTransformCreate API to create the transform
	and the SecTransform APIs to set the data and to execute the transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DecryptDataFinal (CSSM_CC_HANDLE CCHandle,
                       CSSM_DATA_PTR RemData)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_QueryKeySizeInBits has been deprecated in 10.7 and later.  
	Given that a SecKeyRef abstracts the usage of a key this API so no longer
	needed.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_QueryKeySizeInBits (CSSM_CSP_HANDLE CSPHandle,
                         CSSM_CC_HANDLE CCHandle,
                         const CSSM_KEY *Key,
                         CSSM_KEY_SIZE_PTR KeySize)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateKey has been deprecated in 10.7 and later.  
	To create a symmetrical key call SecKeyGenerateSymmetric.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateKey (CSSM_CC_HANDLE CCHandle,
                  uint32 KeyUsage,
                  uint32 KeyAttr,
                  const CSSM_DATA *KeyLabel,
                  const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                  CSSM_KEY_PTR Key)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateKeyP has been deprecated in 10.7 and later.  
	To create a symmetrical key call SecKeyGenerateSymmetric.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateKeyP (CSSM_CC_HANDLE CCHandle,
                   uint32 KeyUsage,
                   uint32 KeyAttr,
                   const CSSM_DATA *KeyLabel,
                   const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                   CSSM_KEY_PTR Key,
                   CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateKeyPair has been deprecated in 10.7 and later.  
	To create an asymmetrical key call SecKeyGeneratePair.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateKeyPair (CSSM_CC_HANDLE CCHandle,
                      uint32 PublicKeyUsage,
                      uint32 PublicKeyAttr,
                      const CSSM_DATA *PublicKeyLabel,
                      CSSM_KEY_PTR PublicKey,
                      uint32 PrivateKeyUsage,
                      uint32 PrivateKeyAttr,
                      const CSSM_DATA *PrivateKeyLabel,
                      const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                      CSSM_KEY_PTR PrivateKey)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateKeyPairP has been deprecated in 10.7 and later.  
	To create an asymmetrical key call SecKeyGeneratePair.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateKeyPairP (CSSM_CC_HANDLE CCHandle,
                       uint32 PublicKeyUsage,
                       uint32 PublicKeyAttr,
                       const CSSM_DATA *PublicKeyLabel,
                       CSSM_KEY_PTR PublicKey,
                       uint32 PrivateKeyUsage,
                       uint32 PrivateKeyAttr,
                       const CSSM_DATA *PrivateKeyLabel,
                       const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                       CSSM_KEY_PTR PrivateKey,
                       CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateRandom has been deprecated in 10.7 and later.  
	To get random data call SecRandomCopyBytes
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateRandom (CSSM_CC_HANDLE CCHandle,
                     CSSM_DATA_PTR RandomNumber)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CSP_ObtainPrivateKeyFromPublicKey has been deprecated in 10.7 and later.  
	There is not currently a direct replacement for this API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_ObtainPrivateKeyFromPublicKey (CSSM_CSP_HANDLE CSPHandle,
                                        const CSSM_KEY *PublicKey,
                                        CSSM_KEY_PTR PrivateKey)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_WrapKey has been deprecated in 10.7 and later.  
	This is replaced with the SecKeyWrapSymmetric API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_WrapKey (CSSM_CC_HANDLE CCHandle,
              const CSSM_ACCESS_CREDENTIALS *AccessCred,
              const CSSM_KEY *Key,
              const CSSM_DATA *DescriptiveData,
              CSSM_WRAP_KEY_PTR WrappedKey)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_UnwrapKey has been deprecated in 10.7 and later.  
	This is replaced with the SecKeyUnwrapSymmetric API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_UnwrapKey (CSSM_CC_HANDLE CCHandle,
                const CSSM_KEY *PublicKey,
                const CSSM_WRAP_KEY *WrappedKey,
                uint32 KeyUsage,
                uint32 KeyAttr,
                const CSSM_DATA *KeyLabel,
                const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                CSSM_KEY_PTR UnwrappedKey,
                CSSM_DATA_PTR DescriptiveData)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_WrapKeyP has been deprecated in 10.7 and later.  
	This is replaced with the SecKeyWrapSymmetric API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_WrapKeyP (CSSM_CC_HANDLE CCHandle,
               const CSSM_ACCESS_CREDENTIALS *AccessCred,
               const CSSM_KEY *Key,
               const CSSM_DATA *DescriptiveData,
               CSSM_WRAP_KEY_PTR WrappedKey,
               CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_WrapKeyP has been deprecated in 10.7 and later.  
	This is replaced with the SecKeyUnwrapSymmetric API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_UnwrapKeyP (CSSM_CC_HANDLE CCHandle,
                 const CSSM_KEY *PublicKey,
                 const CSSM_WRAP_KEY *WrappedKey,
                 uint32 KeyUsage,
                 uint32 KeyAttr,
                 const CSSM_DATA *KeyLabel,
                 const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                 CSSM_KEY_PTR UnwrappedKey,
                 CSSM_DATA_PTR DescriptiveData,
                 CSSM_PRIVILEGE Privilege)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DeriveKey has been deprecated in 10.7 and later.  
	This is replaced with the SecKeyDeriveFromPassword API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DeriveKey (CSSM_CC_HANDLE CCHandle,
                CSSM_DATA_PTR Param,
                uint32 KeyUsage,
                uint32 KeyAttr,
                const CSSM_DATA *KeyLabel,
                const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                CSSM_KEY_PTR DerivedKey)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_FreeKey has been deprecated in 10.7 and later.  There is no 
	alternate API. If the key in question is in a keychain calling 
	SecItemDelete will delete the key.  If it is just a free standing key
	calling CFRelease on the SecKeyRef will delete the key.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_FreeKey (CSSM_CSP_HANDLE CSPHandle,
              const CSSM_ACCESS_CREDENTIALS *AccessCred,
              CSSM_KEY_PTR KeyPtr,
              CSSM_BOOL Delete)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_GenerateAlgorithmParams has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GenerateAlgorithmParams (CSSM_CC_HANDLE CCHandle,
                              uint32 ParamBits,
                              CSSM_DATA_PTR Param)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Miscellaneous Functions for Cryptographic Services */

/* --------------------------------------------------------------------------
	CSSM_CSP_GetOperationalStatistics has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_GetOperationalStatistics (CSSM_CSP_HANDLE CSPHandle,
                                   CSSM_CSP_OPERATIONAL_STATISTICS *Statistics)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* --------------------------------------------------------------------------
	CSSM_GetTimeValue has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_GetTimeValue (CSSM_CSP_HANDLE CSPHandle,
                   CSSM_ALGORITHMS TimeAlgorithm,
                   CSSM_DATA *TimeData)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_RetrieveUniqueId has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.  One could call CFUUIDCreate to create a unique ID.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_RetrieveUniqueId (CSSM_CSP_HANDLE CSPHandle,
                       CSSM_DATA_PTR UniqueID)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_RetrieveCounter has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_RetrieveCounter (CSSM_CSP_HANDLE CSPHandle,
                      CSSM_DATA_PTR Counter)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_VerifyDevice has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_VerifyDevice (CSSM_CSP_HANDLE CSPHandle,
                   const CSSM_DATA *DeviceCert)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Extensibility Functions for Cryptographic Services */

/* --------------------------------------------------------------------------
	CSSM_CSP_PassThrough has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CSP_PassThrough (CSSM_CC_HANDLE CCHandle,
                      uint32 PassThroughId,
                      const void *InData,
                      void **OutData)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Trust Policy Operations */

/* --------------------------------------------------------------------------
	CSSM_TP_SubmitCredRequest has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_SubmitCredRequest (CSSM_TP_HANDLE TPHandle,
                           const CSSM_TP_AUTHORITY_ID *PreferredAuthority,
                           CSSM_TP_AUTHORITY_REQUEST_TYPE RequestType,
                           const CSSM_TP_REQUEST_SET *RequestInput,
                           const CSSM_TP_CALLERAUTH_CONTEXT *CallerAuthContext,
                           sint32 *EstimatedTime,
                           CSSM_DATA_PTR ReferenceIdentifier)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_RetrieveCredResult has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_RetrieveCredResult (CSSM_TP_HANDLE TPHandle,
                            const CSSM_DATA *ReferenceIdentifier,
                            const CSSM_TP_CALLERAUTH_CONTEXT *CallerAuthCredentials,
                            sint32 *EstimatedTime,
                            CSSM_BOOL *ConfirmationRequired,
                            CSSM_TP_RESULT_SET_PTR *RetrieveOutput)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_ConfirmCredResult has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_ConfirmCredResult (CSSM_TP_HANDLE TPHandle,
                           const CSSM_DATA *ReferenceIdentifier,
                           const CSSM_TP_CALLERAUTH_CONTEXT *CallerAuthCredentials,
                           const CSSM_TP_CONFIRM_RESPONSE *Responses,
                           const CSSM_TP_AUTHORITY_ID *PreferredAuthority)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_ReceiveConfirmation has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_ReceiveConfirmation (CSSM_TP_HANDLE TPHandle,
                             const CSSM_DATA *ReferenceIdentifier,
                             CSSM_TP_CONFIRM_RESPONSE_PTR *Responses,
                             sint32 *ElapsedTime)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertReclaimKey has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertReclaimKey (CSSM_TP_HANDLE TPHandle,
                        const CSSM_CERTGROUP *CertGroup,
                        uint32 CertIndex,
                        CSSM_LONG_HANDLE KeyCacheHandle,
                        CSSM_CSP_HANDLE CSPHandle,
                        const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertReclaimAbort has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertReclaimAbort (CSSM_TP_HANDLE TPHandle,
                          CSSM_LONG_HANDLE KeyCacheHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_FormRequest has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_FormRequest (CSSM_TP_HANDLE TPHandle,
                     const CSSM_TP_AUTHORITY_ID *PreferredAuthority,
                     CSSM_TP_FORM_TYPE FormType,
                     CSSM_DATA_PTR BlankForm)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_FormSubmit has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_FormSubmit (CSSM_TP_HANDLE TPHandle,
                    CSSM_TP_FORM_TYPE FormType,
                    const CSSM_DATA *Form,
                    const CSSM_TP_AUTHORITY_ID *ClearanceAuthority,
                    const CSSM_TP_AUTHORITY_ID *RepresentedAuthority,
                    CSSM_ACCESS_CREDENTIALS_PTR Credentials)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertGroupVerify has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertGroupVerify (CSSM_TP_HANDLE TPHandle,
                         CSSM_CL_HANDLE CLHandle,
                         CSSM_CSP_HANDLE CSPHandle,
                         const CSSM_CERTGROUP *CertGroupToBeVerified,
                         const CSSM_TP_VERIFY_CONTEXT *VerifyContext,
                         CSSM_TP_VERIFY_CONTEXT_RESULT_PTR VerifyContextResult)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertCreateTemplate has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertCreateTemplate (CSSM_TP_HANDLE TPHandle,
                            CSSM_CL_HANDLE CLHandle,
                            uint32 NumberOfFields,
                            const CSSM_FIELD *CertFields,
                            CSSM_DATA_PTR CertTemplate)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertGetAllTemplateFields has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertGetAllTemplateFields (CSSM_TP_HANDLE TPHandle,
                                  CSSM_CL_HANDLE CLHandle,
                                  const CSSM_DATA *CertTemplate,
                                  uint32 *NumberOfFields,
                                  CSSM_FIELD_PTR *CertFields)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertSign has been deprecated in 10.7 and later.  
	The replacement API is SecSignTransformCreate.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertSign (CSSM_TP_HANDLE TPHandle,
                  CSSM_CL_HANDLE CLHandle,
                  CSSM_CC_HANDLE CCHandle,
                  const CSSM_DATA *CertTemplateToBeSigned,
                  const CSSM_CERTGROUP *SignerCertGroup,
                  const CSSM_TP_VERIFY_CONTEXT *SignerVerifyContext,
                  CSSM_TP_VERIFY_CONTEXT_RESULT_PTR SignerVerifyResult,
                  CSSM_DATA_PTR SignedCert)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CrlVerify has been deprecated in 10.7 and later.  
	The replacement API is SecVerifyTransformCreate.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CrlVerify (CSSM_TP_HANDLE TPHandle,
                   CSSM_CL_HANDLE CLHandle,
                   CSSM_CSP_HANDLE CSPHandle,
                   const CSSM_ENCODED_CRL *CrlToBeVerified,
                   const CSSM_CERTGROUP *SignerCertGroup,
                   const CSSM_TP_VERIFY_CONTEXT *VerifyContext,
                   CSSM_TP_VERIFY_CONTEXT_RESULT_PTR RevokerVerifyResult)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CrlCreateTemplate has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CrlCreateTemplate (CSSM_TP_HANDLE TPHandle,
                           CSSM_CL_HANDLE CLHandle,
                           uint32 NumberOfFields,
                           const CSSM_FIELD *CrlFields,
                           CSSM_DATA_PTR NewCrlTemplate)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertRevoke has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertRevoke (CSSM_TP_HANDLE TPHandle,
                    CSSM_CL_HANDLE CLHandle,
                    CSSM_CSP_HANDLE CSPHandle,
                    const CSSM_DATA *OldCrlTemplate,
                    const CSSM_CERTGROUP *CertGroupToBeRevoked,
                    const CSSM_CERTGROUP *RevokerCertGroup,
                    const CSSM_TP_VERIFY_CONTEXT *RevokerVerifyContext,
                    CSSM_TP_VERIFY_CONTEXT_RESULT_PTR RevokerVerifyResult,
                    CSSM_TP_CERTCHANGE_REASON Reason,
                    CSSM_DATA_PTR NewCrlTemplate)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertRemoveFromCrlTemplate has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertRemoveFromCrlTemplate (CSSM_TP_HANDLE TPHandle,
                                   CSSM_CL_HANDLE CLHandle,
                                   CSSM_CSP_HANDLE CSPHandle,
                                   const CSSM_DATA *OldCrlTemplate,
                                   const CSSM_CERTGROUP *CertGroupToBeRemoved,
                                   const CSSM_CERTGROUP *RevokerCertGroup,
                                   const CSSM_TP_VERIFY_CONTEXT *RevokerVerifyContext,
                                   CSSM_TP_VERIFY_CONTEXT_RESULT_PTR RevokerVerifyResult,
                                   CSSM_DATA_PTR NewCrlTemplate)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CrlSign has been deprecated in 10.7 and later.  
	The replacement API is SecVerifyTransformCreate.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CrlSign (CSSM_TP_HANDLE TPHandle,
                 CSSM_CL_HANDLE CLHandle,
                 CSSM_CC_HANDLE CCHandle,
                 const CSSM_ENCODED_CRL *CrlToBeSigned,
                 const CSSM_CERTGROUP *SignerCertGroup,
                 const CSSM_TP_VERIFY_CONTEXT *SignerVerifyContext,
                 CSSM_TP_VERIFY_CONTEXT_RESULT_PTR SignerVerifyResult,
                 CSSM_DATA_PTR SignedCrl)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_ApplyCrlToDb has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_ApplyCrlToDb (CSSM_TP_HANDLE TPHandle,
                      CSSM_CL_HANDLE CLHandle,
                      CSSM_CSP_HANDLE CSPHandle,
                      const CSSM_ENCODED_CRL *CrlToBeApplied,
                      const CSSM_CERTGROUP *SignerCertGroup,
                      const CSSM_TP_VERIFY_CONTEXT *ApplyCrlVerifyContext,
                      CSSM_TP_VERIFY_CONTEXT_RESULT_PTR ApplyCrlVerifyResult)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertGroupConstruct has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertGroupConstruct (CSSM_TP_HANDLE TPHandle,
                            CSSM_CL_HANDLE CLHandle,
                            CSSM_CSP_HANDLE CSPHandle,
                            const CSSM_DL_DB_LIST *DBList,
                            const void *ConstructParams,
                            const CSSM_CERTGROUP *CertGroupFrag,
                            CSSM_CERTGROUP_PTR *CertGroup)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertGroupPrune has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertGroupPrune (CSSM_TP_HANDLE TPHandle,
                        CSSM_CL_HANDLE CLHandle,
                        const CSSM_DL_DB_LIST *DBList,
                        const CSSM_CERTGROUP *OrderedCertGroup,
                        CSSM_CERTGROUP_PTR *PrunedCertGroup)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_CertGroupToTupleGroup has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_CertGroupToTupleGroup (CSSM_TP_HANDLE TPHandle,
                               CSSM_CL_HANDLE CLHandle,
                               const CSSM_CERTGROUP *CertGroup,
                               CSSM_TUPLEGROUP_PTR *TupleGroup)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_TupleGroupToCertGroup has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_TupleGroupToCertGroup (CSSM_TP_HANDLE TPHandle,
                               CSSM_CL_HANDLE CLHandle,
                               const CSSM_TUPLEGROUP *TupleGroup,
                               CSSM_CERTGROUP_PTR *CertTemplates)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_TP_PassThrough has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_TP_PassThrough (CSSM_TP_HANDLE TPHandle,
                     CSSM_CL_HANDLE CLHandle,
                     CSSM_CC_HANDLE CCHandle,
                     const CSSM_DL_DB_LIST *DBList,
                     uint32 PassThroughId,
                     const void *InputParams,
                     void **OutputParams)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Authorization Computation Operations */

/* --------------------------------------------------------------------------
	CSSM_AC_AuthCompute has been deprecated in 10.7 and later.  
	Please see the APIs in the SecAccess.h file for a replacement.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_AC_AuthCompute (CSSM_AC_HANDLE ACHandle,
                     const CSSM_TUPLEGROUP *BaseAuthorizations,
                     const CSSM_TUPLEGROUP *Credentials,
                     uint32 NumberOfRequestors,
                     const CSSM_LIST *Requestors,
                     const CSSM_LIST *RequestedAuthorizationPeriod,
                     const CSSM_LIST *RequestedAuthorization,
                     CSSM_TUPLEGROUP_PTR AuthorizationResult)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_AC_PassThrough has been deprecated in 10.7 and later.  
	Please see the APIs in the SecAccess.h file for a replacement.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_AC_PassThrough (CSSM_AC_HANDLE ACHandle,
                     CSSM_TP_HANDLE TPHandle,
                     CSSM_CL_HANDLE CLHandle,
                     CSSM_CC_HANDLE CCHandle,
                     const CSSM_DL_DB_LIST *DBList,
                     uint32 PassThroughId,
                     const void *InputParams,
                     void **OutputParams)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Certificate Library Operations */

/* --------------------------------------------------------------------------
	CSSM_CL_CertCreateTemplate has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertCreateTemplate (CSSM_CL_HANDLE CLHandle,
                            uint32 NumberOfFields,
                            const CSSM_FIELD *CertFields,
                            CSSM_DATA_PTR CertTemplate)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGetAllTemplateFields has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGetAllTemplateFields (CSSM_CL_HANDLE CLHandle,
                                  const CSSM_DATA *CertTemplate,
                                  uint32 *NumberOfFields,
                                  CSSM_FIELD_PTR *CertFields)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertSign has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertSign (CSSM_CL_HANDLE CLHandle,
                  CSSM_CC_HANDLE CCHandle,
                  const CSSM_DATA *CertTemplate,
                  const CSSM_FIELD *SignScope,
                  uint32 ScopeSize,
                  CSSM_DATA_PTR SignedCert)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertVerify has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertVerify (CSSM_CL_HANDLE CLHandle,
                    CSSM_CC_HANDLE CCHandle,
                    const CSSM_DATA *CertToBeVerified,
                    const CSSM_DATA *SignerCert,
                    const CSSM_FIELD *VerifyScope,
                    uint32 ScopeSize)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertVerifyWithKey has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertVerifyWithKey (CSSM_CL_HANDLE CLHandle,
                           CSSM_CC_HANDLE CCHandle,
                           const CSSM_DATA *CertToBeVerified)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertVerifyWithKey has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGetFirstFieldValue (CSSM_CL_HANDLE CLHandle,
                                const CSSM_DATA *Cert,
                                const CSSM_OID *CertField,
                                CSSM_HANDLE_PTR ResultsHandle,
                                uint32 *NumberOfMatchedFields,
                                CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGetNextFieldValue has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGetNextFieldValue (CSSM_CL_HANDLE CLHandle,
                               CSSM_HANDLE ResultsHandle,
                               CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertAbortQuery has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertAbortQuery (CSSM_CL_HANDLE CLHandle,
                        CSSM_HANDLE ResultsHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGetKeyInfo has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGetKeyInfo (CSSM_CL_HANDLE CLHandle,
                        const CSSM_DATA *Cert,
                        CSSM_KEY_PTR *Key)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGetAllFields has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGetAllFields (CSSM_CL_HANDLE CLHandle,
                          const CSSM_DATA *Cert,
                          uint32 *NumberOfFields,
                          CSSM_FIELD_PTR *CertFields)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_FreeFields has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_FreeFields (CSSM_CL_HANDLE CLHandle,
                    uint32 NumberOfFields,
                    CSSM_FIELD_PTR *Fields)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_FreeFieldValue has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_FreeFieldValue (CSSM_CL_HANDLE CLHandle,
                        const CSSM_OID *CertOrCrlOid,
                        CSSM_DATA_PTR Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertCache has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertCache (CSSM_CL_HANDLE CLHandle,
                   const CSSM_DATA *Cert,
                   CSSM_HANDLE_PTR CertHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGetFirstCachedFieldValue has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGetFirstCachedFieldValue (CSSM_CL_HANDLE CLHandle,
                                      CSSM_HANDLE CertHandle,
                                      const CSSM_OID *CertField,
                                      CSSM_HANDLE_PTR ResultsHandle,
                                      uint32 *NumberOfMatchedFields,
                                      CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGetNextCachedFieldValue has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGetNextCachedFieldValue (CSSM_CL_HANDLE CLHandle,
                                     CSSM_HANDLE ResultsHandle,
                                     CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertAbortCache has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertAbortCache (CSSM_CL_HANDLE CLHandle,
                        CSSM_HANDLE CertHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGroupToSignedBundle has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGroupToSignedBundle (CSSM_CL_HANDLE CLHandle,
                                 CSSM_CC_HANDLE CCHandle,
                                 const CSSM_CERTGROUP *CertGroupToBundle,
                                 const CSSM_CERT_BUNDLE_HEADER *BundleInfo,
                                 CSSM_DATA_PTR SignedBundle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertGroupFromVerifiedBundle has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertGroupFromVerifiedBundle (CSSM_CL_HANDLE CLHandle,
                                     CSSM_CC_HANDLE CCHandle,
                                     const CSSM_CERT_BUNDLE *CertBundle,
                                     const CSSM_DATA *SignerCert,
                                     CSSM_CERTGROUP_PTR *CertGroup)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CertDescribeFormat has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CertDescribeFormat (CSSM_CL_HANDLE CLHandle,
                            uint32 *NumberOfFields,
                            CSSM_OID_PTR *OidList)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlCreateTemplate has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlCreateTemplate (CSSM_CL_HANDLE CLHandle,
                           uint32 NumberOfFields,
                           const CSSM_FIELD *CrlTemplate,
                           CSSM_DATA_PTR NewCrl)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlSetFields has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlSetFields (CSSM_CL_HANDLE CLHandle,
                      uint32 NumberOfFields,
                      const CSSM_FIELD *CrlTemplate,
                      const CSSM_DATA *OldCrl,
                      CSSM_DATA_PTR ModifiedCrl)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlAddCert has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlAddCert (CSSM_CL_HANDLE CLHandle,
                    CSSM_CC_HANDLE CCHandle,
                    const CSSM_DATA *Cert,
                    uint32 NumberOfFields,
                    const CSSM_FIELD *CrlEntryFields,
                    const CSSM_DATA *OldCrl,
                    CSSM_DATA_PTR NewCrl)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlRemoveCert has been deprecated in 10.7 and later.  
	There is currently no direct replacement. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlRemoveCert (CSSM_CL_HANDLE CLHandle,
                       const CSSM_DATA *Cert,
                       const CSSM_DATA *OldCrl,
                       CSSM_DATA_PTR NewCrl)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlSign has been deprecated in 10.7 and later.  
	The replacement API would be to use the SecSignTransformCreate transform.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlSign (CSSM_CL_HANDLE CLHandle,
                 CSSM_CC_HANDLE CCHandle,
                 const CSSM_DATA *UnsignedCrl,
                 const CSSM_FIELD *SignScope,
                 uint32 ScopeSize,
                 CSSM_DATA_PTR SignedCrl)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlVerify has been deprecated in 10.7 and later.  
	The replacement API would be to use the SecVerifyTransformCreate transform. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlVerify (CSSM_CL_HANDLE CLHandle,
                   CSSM_CC_HANDLE CCHandle,
                   const CSSM_DATA *CrlToBeVerified,
                   const CSSM_DATA *SignerCert,
                   const CSSM_FIELD *VerifyScope,
                   uint32 ScopeSize)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlVerifyWithKey has been deprecated in 10.7 and later.  
	The replacement API would be to use the SecVerifyTransformCreate transform. 
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlVerifyWithKey (CSSM_CL_HANDLE CLHandle,
                          CSSM_CC_HANDLE CCHandle,
                          const CSSM_DATA *CrlToBeVerified)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_IsCertInCrl has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_IsCertInCrl (CSSM_CL_HANDLE CLHandle,
                     const CSSM_DATA *Cert,
                     const CSSM_DATA *Crl,
                     CSSM_BOOL *CertFound)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlGetFirstFieldValue has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlGetFirstFieldValue (CSSM_CL_HANDLE CLHandle,
                               const CSSM_DATA *Crl,
                               const CSSM_OID *CrlField,
                               CSSM_HANDLE_PTR ResultsHandle,
                               uint32 *NumberOfMatchedFields,
                               CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlGetNextFieldValue has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlGetNextFieldValue (CSSM_CL_HANDLE CLHandle,
                              CSSM_HANDLE ResultsHandle,
                              CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlAbortQuery has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlAbortQuery (CSSM_CL_HANDLE CLHandle,
                       CSSM_HANDLE ResultsHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlGetAllFields has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlGetAllFields (CSSM_CL_HANDLE CLHandle,
                         const CSSM_DATA *Crl,
                         uint32 *NumberOfCrlFields,
                         CSSM_FIELD_PTR *CrlFields)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlCache has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlCache (CSSM_CL_HANDLE CLHandle,
                  const CSSM_DATA *Crl,
                  CSSM_HANDLE_PTR CrlHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_IsCertInCachedCrl has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_IsCertInCachedCrl (CSSM_CL_HANDLE CLHandle,
                           const CSSM_DATA *Cert,
                           CSSM_HANDLE CrlHandle,
                           CSSM_BOOL *CertFound,
                           CSSM_DATA_PTR CrlRecordIndex)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlGetFirstCachedFieldValue has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlGetFirstCachedFieldValue (CSSM_CL_HANDLE CLHandle,
                                     CSSM_HANDLE CrlHandle,
                                     const CSSM_DATA *CrlRecordIndex,
                                     const CSSM_OID *CrlField,
                                     CSSM_HANDLE_PTR ResultsHandle,
                                     uint32 *NumberOfMatchedFields,
                                     CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlGetNextCachedFieldValue has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlGetNextCachedFieldValue (CSSM_CL_HANDLE CLHandle,
                                    CSSM_HANDLE ResultsHandle,
                                    CSSM_DATA_PTR *Value)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlGetAllCachedRecordFields has been deprecated in 10.7 and later.  
	This is replaced with the SecCertificateCopyValues API
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlGetAllCachedRecordFields (CSSM_CL_HANDLE CLHandle,
                                     CSSM_HANDLE CrlHandle,
                                     const CSSM_DATA *CrlRecordIndex,
                                     uint32 *NumberOfFields,
                                     CSSM_FIELD_PTR *CrlFields)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlAbortCache has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlAbortCache (CSSM_CL_HANDLE CLHandle,
                       CSSM_HANDLE CrlHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_CrlDescribeFormat has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_CrlDescribeFormat (CSSM_CL_HANDLE CLHandle,
                           uint32 *NumberOfFields,
                           CSSM_OID_PTR *OidList)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_CL_PassThrough has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_CL_PassThrough (CSSM_CL_HANDLE CLHandle,
                     CSSM_CC_HANDLE CCHandle,
                     uint32 PassThroughId,
                     const void *InputParams,
                     void **OutputParams)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Data Storage Library Operations */

/* --------------------------------------------------------------------------
	CSSM_DL_DbOpen has been deprecated in 10.7 and later.  
	The replacement API is SecKeychainOpen
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DbOpen (CSSM_DL_HANDLE DLHandle,
                const char *DbName,
                const CSSM_NET_ADDRESS *DbLocation,
                CSSM_DB_ACCESS_TYPE AccessRequest,
                const CSSM_ACCESS_CREDENTIALS *AccessCred,
                const void *OpenParameters,
                CSSM_DB_HANDLE *DbHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DbClose has been deprecated in 10.7 and later.  There is no alternate
	API as this call is only needed when calling CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DbClose (CSSM_DL_DB_HANDLE DLDBHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DbCreate has been deprecated in 10.7 and later.  
	The replacement API is SecKeychainCreate
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DbCreate (CSSM_DL_HANDLE DLHandle,
                  const char *DbName,
                  const CSSM_NET_ADDRESS *DbLocation,
                  const CSSM_DBINFO *DBInfo,
                  CSSM_DB_ACCESS_TYPE AccessRequest,
                  const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
                  const void *OpenParameters,
                  CSSM_DB_HANDLE *DbHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DbDelete has been deprecated in 10.7 and later.  
	The replacement API is SecKeychainDelete
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DbDelete (CSSM_DL_HANDLE DLHandle,
                  const char *DbName,
                  const CSSM_NET_ADDRESS *DbLocation,
                  const CSSM_ACCESS_CREDENTIALS *AccessCred) 
				DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_CreateRelation has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_CreateRelation (CSSM_DL_DB_HANDLE DLDBHandle,
                        CSSM_DB_RECORDTYPE RelationID,
                        const char *RelationName,
                        uint32 NumberOfAttributes,
                        const CSSM_DB_SCHEMA_ATTRIBUTE_INFO *pAttributeInfo,
                        uint32 NumberOfIndexes,
                        const CSSM_DB_SCHEMA_INDEX_INFO *pIndexInfo)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DestroyRelation has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DestroyRelation (CSSM_DL_DB_HANDLE DLDBHandle,
                         CSSM_DB_RECORDTYPE RelationID)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_Authenticate has been deprecated in 10.7 and later.  
	The replacement API is SecKeychainUnlock
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_Authenticate (CSSM_DL_DB_HANDLE DLDBHandle,
                      CSSM_DB_ACCESS_TYPE AccessRequest,
                      const CSSM_ACCESS_CREDENTIALS *AccessCred)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_GetDbAcl has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_GetDbAcl (CSSM_DL_DB_HANDLE DLDBHandle,
                  const CSSM_STRING *SelectionTag,
                  uint32 *NumberOfAclInfos,
                  CSSM_ACL_ENTRY_INFO_PTR *AclInfos)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_ChangeDbAcl has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_ChangeDbAcl (CSSM_DL_DB_HANDLE DLDBHandle,
                     const CSSM_ACCESS_CREDENTIALS *AccessCred,
                     const CSSM_ACL_EDIT *AclEdit)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_GetDbOwner has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_GetDbOwner (CSSM_DL_DB_HANDLE DLDBHandle,
                    CSSM_ACL_OWNER_PROTOTYPE_PTR Owner)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_ChangeDbOwner has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_ChangeDbOwner (CSSM_DL_DB_HANDLE DLDBHandle,
                       const CSSM_ACCESS_CREDENTIALS *AccessCred,
                       const CSSM_ACL_OWNER_PROTOTYPE *NewOwner)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_GetDbNames has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_GetDbNames (CSSM_DL_HANDLE DLHandle,
                    CSSM_NAME_LIST_PTR *NameList)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_GetDbNameFromHandle has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_GetDbNameFromHandle (CSSM_DL_DB_HANDLE DLDBHandle,
                             char **DbName)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_FreeNameList has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_FreeNameList (CSSM_DL_HANDLE DLHandle,
                      CSSM_NAME_LIST_PTR NameList)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_Authenticate has been deprecated in 10.7 and later.  
	The replacement API are SecKeychainAddInternetPassword,
	SecKeychainAddGenericPassword, SecItemAdd
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DataInsert (CSSM_DL_DB_HANDLE DLDBHandle,
                    CSSM_DB_RECORDTYPE RecordType,
                    const CSSM_DB_RECORD_ATTRIBUTE_DATA *Attributes,
                    const CSSM_DATA *Data,
                    CSSM_DB_UNIQUE_RECORD_PTR *UniqueId)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_Authenticate has been deprecated in 10.7 and later.  
	The replacement API is SecItemDelete
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DataDelete (CSSM_DL_DB_HANDLE DLDBHandle,
                    const CSSM_DB_UNIQUE_RECORD *UniqueRecordIdentifier)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_Authenticate has been deprecated in 10.7 and later.  
	The replacement API is SecItemUpdate
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DataModify (CSSM_DL_DB_HANDLE DLDBHandle,
                    CSSM_DB_RECORDTYPE RecordType,
                    CSSM_DB_UNIQUE_RECORD_PTR UniqueRecordIdentifier,
                    const CSSM_DB_RECORD_ATTRIBUTE_DATA *AttributesToBeModified,
                    const CSSM_DATA *DataToBeModified,
                    CSSM_DB_MODIFY_MODE ModifyMode)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DataGetFirst has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs. SecItemCopyMatching may return multiple items if specified to
	do so.  The user could then retrieve the first in the list of items.
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DataGetFirst (CSSM_DL_DB_HANDLE DLDBHandle,
                      const CSSM_QUERY *Query,
                      CSSM_HANDLE_PTR ResultsHandle,
                      CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
                      CSSM_DATA_PTR Data,
                      CSSM_DB_UNIQUE_RECORD_PTR *UniqueId)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DataGetNext has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs. SecItemCopyMatching may return multiple items if specified to
	do so.  The user could then retrieve the items in the list
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DataGetNext (CSSM_DL_DB_HANDLE DLDBHandle,
                     CSSM_HANDLE ResultsHandle,
                     CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
                     CSSM_DATA_PTR Data,
                     CSSM_DB_UNIQUE_RECORD_PTR *UniqueId)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DataAbortQuery has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DataAbortQuery (CSSM_DL_DB_HANDLE DLDBHandle,
                        CSSM_HANDLE ResultsHandle)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_DataGetFromUniqueRecordId has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_DataGetFromUniqueRecordId (CSSM_DL_DB_HANDLE DLDBHandle,
                              const CSSM_DB_UNIQUE_RECORD *UniqueRecord,
                              CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
                              CSSM_DATA_PTR Data)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_FreeUniqueRecord has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_FreeUniqueRecord (CSSM_DL_DB_HANDLE DLDBHandle,
                          CSSM_DB_UNIQUE_RECORD_PTR UniqueRecord)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* --------------------------------------------------------------------------
	CSSM_DL_PassThrough has been deprecated in 10.7 and later.  
	There is no alternate API as this call is only needed when calling 
	CDSA APIs
   -------------------------------------------------------------------------- */
CSSM_RETURN CSSMAPI
CSSM_DL_PassThrough (CSSM_DL_DB_HANDLE DLDBHandle,
                uint32 PassThroughId,
                const void *InputParams,
                void **OutputParams)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#ifdef __cplusplus
}
#endif

#endif /* _CSSMAPI_H_ */
