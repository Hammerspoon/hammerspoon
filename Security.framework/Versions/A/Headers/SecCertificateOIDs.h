/*
 * Copyright (c) 2002-2012 Apple Inc. All Rights Reserved.
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
 */

/*!
	@header SecCertificateOIDs
	These constants are used to access entries in the dictionary returned by
	SecCertificateCopyValues, which are the parsed field from a certificate. 
*/

#ifndef _SECURITY_SECCERTIFICATEOIDS_H_
#define _SECURITY_SECCERTIFICATEOIDS_H_

#include <CoreFoundation/CFBase.h>
#include <Availability.h>
#include <AvailabilityMacros.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

extern const CFStringRef kSecOIDADC_CERT_POLICY __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_CERT_POLICY __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EKU_CODE_SIGNING __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EKU_CODE_SIGNING_DEV __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EKU_ICHAT_ENCRYPTION __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EKU_ICHAT_SIGNING __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EKU_RESOURCE_SIGNING __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EKU_SYSTEM_IDENTITY __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_ADC_APPLE_SIGNING __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_ADC_DEV_SIGNING __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_APPLE_SIGNING __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_CODE_SIGNING __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_INTERMEDIATE_MARKER __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_WWDR_INTERMEDIATE __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_ITMS_INTERMEDIATE __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_AAI_INTERMEDIATE __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAPPLE_EXTENSION_APPLEID_INTERMEDIATE __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAuthorityInfoAccess __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDAuthorityKeyIdentifier __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDBasicConstraints __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDBiometricInfo __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCSSMKeyStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCertIssuer __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCertificatePolicies __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDClientAuth __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCollectiveStateProvinceName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCollectiveStreetAddress __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCommonName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCountryName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCrlDistributionPoints __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCrlNumber __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDCrlReason __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDDOTMAC_CERT_EMAIL_ENCRYPT __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDDOTMAC_CERT_EMAIL_SIGN __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDDOTMAC_CERT_EXTENSION __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDDOTMAC_CERT_IDENTITY __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDDOTMAC_CERT_POLICY __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDDeltaCrlIndicator __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDDescription __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDEKU_IPSec __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDEmailAddress __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDEmailProtection __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDExtendedKeyUsage __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDExtendedKeyUsageAny __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDExtendedUseCodeSigning __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDGivenName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDHoldInstructionCode __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDInvalidityDate __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDIssuerAltName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDIssuingDistributionPoint __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDIssuingDistributionPoints __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDKERBv5_PKINIT_KP_CLIENT_AUTH __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDKERBv5_PKINIT_KP_KDC __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDKeyUsage __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDLocalityName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDMS_NTPrincipalName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDMicrosoftSGC __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDNameConstraints __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDNetscapeCertSequence __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDNetscapeCertType __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDNetscapeSGC __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDOCSPSigning __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDOrganizationName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDOrganizationalUnitName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDPolicyConstraints __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDPolicyMappings __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDPrivateKeyUsagePeriod __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDQC_Statements __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSerialNumber __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDServerAuth __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDStateProvinceName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDStreetAddress __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSubjectAltName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSubjectDirectoryAttributes __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSubjectEmailAddress __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSubjectInfoAccess __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSubjectKeyIdentifier __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSubjectPicture __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSubjectSignatureBitmap __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSurname __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDTimeStamping __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDTitle __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDUseExemptions __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1CertificateIssuerUniqueId __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1CertificateSubjectUniqueId __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1IssuerName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1IssuerNameCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1IssuerNameLDAP __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1IssuerNameStd __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SerialNumber __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1Signature __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SignatureAlgorithm __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SignatureAlgorithmParameters __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SignatureAlgorithmTBS __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SignatureCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SignatureStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectName __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectNameCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectNameLDAP __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectNameStd __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectPublicKey __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectPublicKeyAlgorithm __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectPublicKeyAlgorithmParameters __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1SubjectPublicKeyCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1ValidityNotAfter __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1ValidityNotBefore __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V1Version __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3Certificate __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionCritical __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionId __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionType __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionValue __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionsCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateExtensionsStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3CertificateNumberOfExtensions __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3SignedCertificate __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDX509V3SignedCertificateCStruct __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecOIDSRVName  __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_NA);

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECCERTIFICATEOIDS_H_ */
