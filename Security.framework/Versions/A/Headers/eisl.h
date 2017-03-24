/*
 * Copyright (c) 1999-2002,2004,2011,2014 Apple Inc. All Rights Reserved.
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
 * eisl.h -- Embedded Integrity Services Library Interface
 */

#ifndef _EISL_H_
#define _EISL_H_  1

#include <Security/cssmconfig.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Data Types for Embedded Integrity Services Library */

typedef const void *ISL_ITERATOR_PTR;

typedef const void *ISL_VERIFIED_SIGNATURE_ROOT_PTR;

typedef const void *ISL_VERIFIED_CERTIFICATE_CHAIN_PTR;

typedef const void *ISL_VERIFIED_CERTIFICATE_PTR;

typedef const void *ISL_MANIFEST_SECTION_PTR;

typedef const void *ISL_VERIFIED_MODULE_PTR;

typedef void (*ISL_FUNCTION_PTR)(void);

typedef struct isl_data {
    CSSM_SIZE Length; /* in bytes */
    uint8 *Data;
} ISL_DATA, *ISL_DATA_PTR;

typedef struct isl_const_data {
    CSSM_SIZE Length; /* in bytes */
    const uint8 *Data;
} ISL_CONST_DATA, *ISL_CONST_DATA_PTR;

typedef enum isl_status {
	ISL_OK = 0,
	ISL_FAIL = -1
} ISL_STATUS;


/* Embedded Integrity Services Library Functions */

ISL_VERIFIED_MODULE_PTR
EISL_SelfCheck ();

ISL_VERIFIED_MODULE_PTR
EISL_VerifyAndLoadModuleAndCredentialData (const ISL_CONST_DATA CredentialsImage,
                                           const ISL_CONST_DATA ModuleSearchPath,
                                           const ISL_CONST_DATA Name,
                                           const ISL_CONST_DATA Signer,
                                           const ISL_CONST_DATA PublicKey);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyAndLoadModuleAndCredentialDataWithCertificate (const ISL_CONST_DATA CredentialsImage,
                                                          const ISL_CONST_DATA ModuleSearchPath,
                                                          const ISL_CONST_DATA Name,
                                                          const ISL_CONST_DATA Signer,
                                                          const ISL_CONST_DATA Certificate);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyAndLoadModuleAndCredentials (ISL_CONST_DATA Credentials,
                                        ISL_CONST_DATA Name,
                                        ISL_CONST_DATA Signer,
                                        ISL_CONST_DATA PublicKey);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyAndLoadModuleAndCredentialsWithCertificate (const ISL_CONST_DATA Credentials,
                                                       const ISL_CONST_DATA Name,
                                                       const ISL_CONST_DATA Signer,
                                                       const ISL_CONST_DATA Certificate);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyLoadedModuleAndCredentialData (const ISL_CONST_DATA CredentialsImage,
                                          const ISL_CONST_DATA ModuleSearchPath,
                                          const ISL_CONST_DATA Name,
                                          const ISL_CONST_DATA Signer,
                                          const ISL_CONST_DATA PublicKey);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyLoadedModuleAndCredentialDataWithCertificate (const ISL_CONST_DATA CredentialsImage,
                                                         const ISL_CONST_DATA ModuleSearchPath,
                                                         const ISL_CONST_DATA Name,
                                                         const ISL_CONST_DATA Signer,
                                                         const ISL_CONST_DATA Certificate);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyLoadedModuleAndCredentials (ISL_CONST_DATA Credentials,
                                       ISL_CONST_DATA Name,
                                       ISL_CONST_DATA Signer,
                                       ISL_CONST_DATA PublicKey);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyLoadedModuleAndCredentialsWithCertificate (const ISL_CONST_DATA Credentials,
                                                      const ISL_CONST_DATA Name,
                                                      const ISL_CONST_DATA Signer,
                                                      const ISL_CONST_DATA Certificate);

ISL_VERIFIED_CERTIFICATE_CHAIN_PTR
EISL_GetCertificateChain (ISL_VERIFIED_MODULE_PTR Module);

uint32
EISL_ContinueVerification (ISL_VERIFIED_MODULE_PTR Module,
                           uint32 WorkFactor);

ISL_VERIFIED_MODULE_PTR
EISL_DuplicateVerifiedModulePtr (ISL_VERIFIED_MODULE_PTR Module);

ISL_STATUS
EISL_RecycleVerifiedModuleCredentials (ISL_VERIFIED_MODULE_PTR Verification);


/* Signature Root Methods */

ISL_VERIFIED_SIGNATURE_ROOT_PTR
EISL_CreateVerifiedSignatureRootWithCredentialData (const ISL_CONST_DATA CredentialsImage,
                                                    const ISL_CONST_DATA ModuleSearchPath,
                                                    const ISL_CONST_DATA Signer,
                                                    const ISL_CONST_DATA PublicKey);

ISL_VERIFIED_SIGNATURE_ROOT_PTR
EISL_CreateVerifiedSignatureRootWithCredentialDataAndCertificate (const ISL_CONST_DATA CredentialsImage,
                                                                  const ISL_CONST_DATA ModuleSearchPath,
                                                                  ISL_VERIFIED_CERTIFICATE_PTR Cert);

ISL_VERIFIED_SIGNATURE_ROOT_PTR
EISL_CreateVerfiedSignatureRoot (ISL_CONST_DATA Credentials,
                                 ISL_CONST_DATA Signer,
                                 ISL_CONST_DATA PublicKey);

ISL_VERIFIED_SIGNATURE_ROOT_PTR
EISL_CreateVerfiedSignatureRootWithCertificate (ISL_CONST_DATA Credentials,
                                                ISL_VERIFIED_CERTIFICATE_PTR Cert);

ISL_MANIFEST_SECTION_PTR
EISL_FindManifestSection (ISL_VERIFIED_SIGNATURE_ROOT_PTR Root,
                          ISL_CONST_DATA Name);

ISL_ITERATOR_PTR
EISL_CreateManifestSectionEnumerator (ISL_VERIFIED_SIGNATURE_ROOT_PTR Root);

ISL_MANIFEST_SECTION_PTR
EISL_GetNextManifestSection (ISL_ITERATOR_PTR Iterator);

ISL_STATUS
EISL_RecycleManifestSectionEnumerator (ISL_ITERATOR_PTR Iterator);

ISL_STATUS
EISL_FindManifestAttribute (ISL_VERIFIED_SIGNATURE_ROOT_PTR Context,
                            ISL_CONST_DATA Name,
                            ISL_CONST_DATA_PTR Value);

ISL_ITERATOR_PTR
EISL_CreateManifestAttributeEnumerator (ISL_VERIFIED_SIGNATURE_ROOT_PTR Context);

ISL_STATUS
EISL_FindSignerInfoAttribute (ISL_VERIFIED_SIGNATURE_ROOT_PTR Context,
                              ISL_CONST_DATA Name,
                              ISL_CONST_DATA_PTR Value);

ISL_ITERATOR_PTR
EISL_CreateSignerInfoAttributeEnumerator (ISL_VERIFIED_SIGNATURE_ROOT_PTR Context);

ISL_STATUS
EISL_GetNextAttribute (ISL_ITERATOR_PTR Iterator,
                       ISL_CONST_DATA_PTR Name,
                       ISL_CONST_DATA_PTR Value);

ISL_STATUS
EISL_RecycleAttributeEnumerator (ISL_ITERATOR_PTR Iterator);

ISL_STATUS
EISL_FindSignatureAttribute (ISL_VERIFIED_SIGNATURE_ROOT_PTR Root,
                             ISL_CONST_DATA Name,
                             ISL_CONST_DATA_PTR Value);

ISL_ITERATOR_PTR
EISL_CreateSignatureAttributeEnumerator (ISL_VERIFIED_SIGNATURE_ROOT_PTR Root);

ISL_STATUS
EISL_GetNextSignatureAttribute (ISL_ITERATOR_PTR Iterator,
                                ISL_CONST_DATA_PTR Name,
                                ISL_CONST_DATA_PTR Value);

ISL_STATUS
EISL_RecycleSignatureAttributeEnumerator (ISL_ITERATOR_PTR Iterator);

ISL_STATUS
EISL_RecycleVerifiedSignatureRoot (ISL_VERIFIED_SIGNATURE_ROOT_PTR Root);


/* Certificate Chain Methods */

const ISL_VERIFIED_CERTIFICATE_CHAIN_PTR
EISL_CreateCertificateChainWithCredentialData (const ISL_CONST_DATA RootIssuer,
                                               const ISL_CONST_DATA PublicKey,
                                               const ISL_CONST_DATA CredentialsImage,
                                               const ISL_CONST_DATA ModuleSearchPath);

ISL_VERIFIED_CERTIFICATE_CHAIN_PTR
EISL_CreateCertificateChainWithCredentialDataAndCertificate (const ISL_CONST_DATA Certificate,
                                                             const ISL_CONST_DATA CredentialsImage,
                                                             const ISL_CONST_DATA ModuleSearchPath);

ISL_VERIFIED_CERTIFICATE_CHAIN_PTR
EISL_CreateCertificateChain (ISL_CONST_DATA RootIssuer,
                             ISL_CONST_DATA PublicKey,
                             ISL_CONST_DATA Credential);

ISL_VERIFIED_CERTIFICATE_CHAIN_PTR
EISL_CreateCertificateChainWithCertificate (const ISL_CONST_DATA Certificate,
                                            const ISL_CONST_DATA Credential);

uint32
EISL_CopyCertificateChain (ISL_VERIFIED_CERTIFICATE_CHAIN_PTR Verification,
                           ISL_VERIFIED_CERTIFICATE_PTR Certs[],
                           uint32 MaxCertificates);

ISL_STATUS
EISL_RecycleVerifiedCertificateChain (ISL_VERIFIED_CERTIFICATE_CHAIN_PTR Chain);


/* Certificate Attribute Methods */

ISL_STATUS
EISL_FindCertificateAttribute (ISL_VERIFIED_CERTIFICATE_PTR Cert,
                               ISL_CONST_DATA Name,
                               ISL_CONST_DATA_PTR Value);

ISL_ITERATOR_PTR
EISL_CreateCertificateAttributeEnumerator (ISL_VERIFIED_CERTIFICATE_PTR Cert);

ISL_STATUS
EISL_GetNextCertificateAttribute (ISL_ITERATOR_PTR CertIterator,
                                  ISL_CONST_DATA_PTR Name,
                                  ISL_CONST_DATA_PTR Value);

ISL_STATUS
EISL_RecycleCertificateAttributeEnumerator (ISL_ITERATOR_PTR CertIterator);


/* Manifest Section Object Methods */

ISL_VERIFIED_SIGNATURE_ROOT_PTR
EISL_GetManifestSignatureRoot (ISL_MANIFEST_SECTION_PTR Section);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyAndLoadModule (ISL_MANIFEST_SECTION_PTR Section);

ISL_VERIFIED_MODULE_PTR
EISL_VerifyLoadedModule (ISL_MANIFEST_SECTION_PTR Section);

ISL_STATUS
EISL_FindManifestSectionAttribute (ISL_MANIFEST_SECTION_PTR Section,
                                   ISL_CONST_DATA Name,
                                   ISL_CONST_DATA_PTR Value);

ISL_ITERATOR_PTR
EISL_CreateManifestSectionAttributeEnumerator (ISL_MANIFEST_SECTION_PTR Section);

ISL_STATUS
EISL_GetNextManifestSectionAttribute (ISL_ITERATOR_PTR Iterator,
                                      ISL_CONST_DATA_PTR Name,
                                      ISL_CONST_DATA_PTR Value);

ISL_STATUS
EISL_RecycleManifestSectionAttributeEnumerator (ISL_ITERATOR_PTR Iterator);

ISL_MANIFEST_SECTION_PTR
EISL_GetModuleManifestSection (ISL_VERIFIED_MODULE_PTR Module);


/* Secure Linkage Services */

ISL_FUNCTION_PTR
EISL_LocateProcedureAddress (ISL_VERIFIED_MODULE_PTR Module,
                             ISL_CONST_DATA Name);

#ifdef MACOSX
#define EISL_GetReturnAddress(Address) \
{\
    /* Platform specific code in here */ \
}
#endif

ISL_STATUS
EISL_CheckAddressWithinModule (ISL_VERIFIED_MODULE_PTR Verification,
                               ISL_FUNCTION_PTR Address);

ISL_STATUS
EISL_CheckDataAddressWithinModule (ISL_VERIFIED_MODULE_PTR Verification,
                                   const void *Address);

void *
EISL_GetLibHandle (ISL_VERIFIED_MODULE_PTR Verification);

#ifdef __cplusplus
}
#endif

#endif /* _EISL_H_ */
