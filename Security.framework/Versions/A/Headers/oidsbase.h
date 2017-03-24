/*
 * Copyright (c) 1999-2001,2003-2004,2008-2014 Apple Inc. All Rights Reserved.
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
 * oidsbase.h -- Basic Object Identifier Macros and Data Types.
 */

#ifndef _OIDSBASE_H_
#define _OIDSBASE_H_  1

#ifdef __cplusplus
extern "C" {
#endif

/* Intel CSSM */

#define INTEL 96, 134, 72, 1, 134, 248, 77
#define INTEL_LENGTH 7

#define INTEL_CDSASECURITY INTEL, 2
#define INTEL_CDSASECURITY_LENGTH (INTEL_LENGTH + 1)

#define INTEL_SEC_FORMATS INTEL_CDSASECURITY, 1
#define INTEL_SEC_FORMATS_LENGTH (INTEL_CDSASECURITY_LENGTH + 1)

#define INTEL_SEC_ALGS INTEL_CDSASECURITY, 2, 5
#define INTEL_SEC_ALGS_LENGTH (INTEL_CDSASECURITY_LENGTH + 2)

#define INTEL_SEC_OBJECT_BUNDLE INTEL_SEC_FORMATS, 4
#define INTEL_SEC_OBJECT_BUNDLE_LENGTH (INTEL_SEC_FORMATS_LENGTH + 1)

#define INTEL_CERT_AND_PRIVATE_KEY_2_0 INTEL_SEC_OBJECT_BUNDLE, 1
#define INTEL_CERT_AND_PRIVATE_KEY_2_0_LENGTH (INTEL_SEC_OBJECT_BUNDLE_LENGTH + 1)

/* Suffix specifying format or representation of a field value */
/* Note that if a format suffix is not specified, a flat data
representation is implied */
#define INTEL_X509_C_DATATYPE 1
#define INTEL_X509_LDAPSTRING_DATATYPE 2

#define OID_ISO_CCITT_DIR_SERVICE 			85
#define OID_DS              				OID_ISO_CCITT_DIR_SERVICE
#define OID_DS_LENGTH       				1
#define OID_ATTR_TYPE        				OID_DS, 4
#define OID_ATTR_TYPE_LENGTH 				OID_DS_LENGTH + 1
#define OID_EXTENSION        				OID_DS, 29
#define OID_EXTENSION_LENGTH 				OID_DS_LENGTH + 1
#define OID_ISO_STANDARD      	 			40
#define OID_ISO_MEMBER         				42
#define OID_US                 				OID_ISO_MEMBER, 134, 72

#define OID_ISO_IDENTIFIED_ORG 				43
#define OID_OSINET             				OID_ISO_IDENTIFIED_ORG, 4
#define OID_GOSIP              				OID_ISO_IDENTIFIED_ORG, 5
#define OID_DOD                				OID_ISO_IDENTIFIED_ORG, 6
#define OID_OIW                				OID_ISO_IDENTIFIED_ORG, 14

#define OID_ITU_RFCDATA_MEMBER_LENGTH		1
#define OID_ITU_RFCDATA						9

/* From the PKCS Standards */
#define OID_ISO_MEMBER_LENGTH 				1
#define OID_US_LENGTH         				OID_ISO_MEMBER_LENGTH + 2
#define OID_RSA               				OID_US, 134, 247, 13
#define OID_RSA_LENGTH        				OID_US_LENGTH + 3
#define OID_RSA_HASH          				OID_RSA, 2
#define OID_RSA_HASH_LENGTH   				OID_RSA_LENGTH + 1
#define OID_RSA_ENCRYPT       				OID_RSA, 3
#define OID_RSA_ENCRYPT_LENGTH	 			OID_RSA_LENGTH + 1
#define OID_PKCS             				OID_RSA, 1
#define OID_PKCS_LENGTH       				OID_RSA_LENGTH +1
#define OID_PKCS_1          				OID_PKCS, 1
#define OID_PKCS_1_LENGTH   				OID_PKCS_LENGTH +1
#define OID_PKCS_2          				OID_PKCS, 2
#define OID_PKCS_3          				OID_PKCS, 3
#define OID_PKCS_3_LENGTH   				OID_PKCS_LENGTH +1
#define OID_PKCS_4          				OID_PKCS, 4
#define OID_PKCS_5          				OID_PKCS, 5
#define OID_PKCS_5_LENGTH   				OID_PKCS_LENGTH +1
#define OID_PKCS_6          				OID_PKCS, 6
#define OID_PKCS_7          				OID_PKCS, 7
#define OID_PKCS_7_LENGTH   				OID_PKCS_LENGTH +1
#define OID_PKCS_8          				OID_PKCS, 8
#define OID_PKCS_9          				OID_PKCS, 9
#define OID_PKCS_9_LENGTH   				OID_PKCS_LENGTH +1
#define OID_PKCS_10         				OID_PKCS, 10
#define OID_PKCS_11          				OID_PKCS, 11
#define OID_PKCS_11_LENGTH   				OID_PKCS_LENGTH +1
#define OID_PKCS_12          				OID_PKCS, 12
#define OID_PKCS_12_LENGTH   				OID_PKCS_LENGTH +1

/* ANSI X9.42 */
#define OID_ANSI_X9_42						OID_US, 206, 62, 2
#define OID_ANSI_X9_42_LEN					OID_US_LENGTH + 3
#define OID_ANSI_X9_42_SCHEME				OID_ANSI_X9_42, 3
#define OID_ANSI_X9_42_SCHEME_LEN			OID_ANSI_X9_42_LEN + 1
#define OID_ANSI_X9_42_NAMED_SCHEME			OID_ANSI_X9_42, 4
#define OID_ANSI_X9_42_NAMED_SCHEME_LEN		OID_ANSI_X9_42_LEN + 1

/* ANSI X9.62 (1 2 840 10045) */
#define OID_ANSI_X9_62						0x2A, 0x86, 0x48, 0xCE, 0x3D
#define OID_ANSI_X9_62_LEN					5
#define OID_ANSI_X9_62_FIELD_TYPE			OID_ANSI_X9_62, 1
#define OID_ANSI_X9_62_PUBKEY_TYPE			OID_ANSI_X9_62, 2
#define OID_ANSI_X9_62_ELL_CURVE			OID_ANSI_X9_62, 3
#define OID_ANSI_X9_62_ELL_CURVE_LEN		OID_ANSI_X9_62_LEN+1
#define OID_ANSI_X9_62_C_TWO_CURVE			OID_ANSI_X9_62_ELL_CURVE, 0
#define OID_ANSI_X9_62_PRIME_CURVE			OID_ANSI_X9_62_ELL_CURVE, 1
#define OID_ANSI_X9_62_SIG_TYPE				OID_ANSI_X9_62, 4
#define OID_ANSI_X9_62_SIG_TYPE_LEN			OID_ANSI_X9_62_LEN+1

/* PKIX */
#define OID_PKIX							OID_DOD, 1, 5, 5, 7
#define OID_PKIX_LENGTH						6
#define OID_PE								OID_PKIX, 1
#define OID_PE_LENGTH						OID_PKIX_LENGTH + 1
#define OID_QT								OID_PKIX, 2
#define OID_QT_LENGTH						OID_PKIX_LENGTH + 1
#define OID_KP								OID_PKIX, 3
#define OID_KP_LENGTH						OID_PKIX_LENGTH + 1
#define OID_OTHER_NAME						OID_PKIX, 8
#define OID_OTHER_NAME_LENGTH				OID_PKIX_LENGTH + 1
#define OID_PDA								OID_PKIX, 9
#define OID_PDA_LENGTH						OID_PKIX_LENGTH + 1
#define OID_QCS								OID_PKIX, 11
#define OID_QCS_LENGTH						OID_PKIX_LENGTH + 1
#define OID_AD								OID_PKIX, 48
#define OID_AD_LENGTH						OID_PKIX_LENGTH + 1
#define OID_AD_OCSP							OID_AD, 1
#define OID_AD_OCSP_LENGTH					OID_AD_LENGTH + 1

/* ETSI */
#define OID_ETSI							0x04, 0x00
#define OID_ETSI_LENGTH						2
#define OID_ETSI_QCS						0x04, 0x00, 0x8E, 0x46, 0x01
#define OID_ETSI_QCS_LENGTH					5

#define OID_OIW_SECSIG        				OID_OIW, 3
#define OID_OIW_LENGTH       				2
#define OID_OIW_SECSIG_LENGTH 				OID_OIW_LENGTH +1

#define OID_OIW_ALGORITHM    				OID_OIW_SECSIG, 2
#define OID_OIW_ALGORITHM_LENGTH   			OID_OIW_SECSIG_LENGTH +1

/* NIST defined digest algorithm arc (2, 16, 840, 1, 101, 3, 4, 2) */
#define OID_NIST_HASHALG					0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02
#define OID_NIST_HASHALG_LENGTH				8

/* Kerberos PKINIT */
#define OID_KERBv5							0x2b, 6, 1, 5, 2
#define OID_KERBv5_LEN						5
#define OID_KERBv5_PKINIT					OID_KERBv5, 3
#define OID_KERBv5_PKINIT_LEN				OID_KERBv5_LEN + 1

/* Certicom (1 3 132) */
#define OID_CERTICOM						0x2B, 0x81, 0x04
#define OID_CERTICOM_LEN					3
#define OID_CERTICOM_ELL_CURVE				OID_CERTICOM, 0
#define OID_CERTICOM_ELL_CURVE_LEN			OID_CERTICOM_LEN+1

/*
 * Apple-specific OID bases
 */

/*
 * apple OBJECT IDENTIFIER ::=
 * 	{ iso(1) member-body(2) US(840) 113635 }
 *
 * BER = 06 06 2A 86 48 86 F7 63
 */
#define APPLE_OID				OID_US, 0x86, 0xf7, 0x63
#define APPLE_OID_LENGTH		OID_US_LENGTH + 3

/* appleDataSecurity OBJECT IDENTIFIER ::=
 *		{ apple 100 }
 *      { 1 2 840 113635 100 }
 *
 * BER = 06 07 2A 86 48 86 F7 63 64
 */
#define APPLE_ADS_OID			APPLE_OID, 0x64
#define APPLE_ADS_OID_LENGTH	APPLE_OID_LENGTH + 1

/*
 * appleTrustPolicy OBJECT IDENTIFIER ::=
 *		{ appleDataSecurity 1 }
 *      { 1 2 840 113635 100 1 }
 *
 * BER = 06 08 2A 86 48 86 F7 63 64 01
 */
#define APPLE_TP_OID			APPLE_ADS_OID, 1
#define APPLE_TP_OID_LENGTH		APPLE_ADS_OID_LENGTH + 1

/*
 *	appleSecurityAlgorithm OBJECT IDENTIFIER ::=
 *		{ appleDataSecurity 2 }
 *      { 1 2 840 113635 100 2 }
 *
 * BER = 06 08 2A 86 48 86 F7 63 64 02
 */
#define APPLE_ALG_OID			APPLE_ADS_OID, 2
#define APPLE_ALG_OID_LENGTH	APPLE_ADS_OID_LENGTH + 1

/*
 * appleDotMacCertificate OBJECT IDENTIFIER ::=
 *		{ appleDataSecurity 3 }
 *      { 1 2 840 113635 100 3 }
 */
#define APPLE_DOTMAC_CERT_OID			APPLE_ADS_OID, 3
#define APPLE_DOTMAC_CERT_OID_LENGTH	APPLE_ADS_OID_LENGTH + 1

/*
 * Basis of Policy OIDs for .mac TP requests
 *
 * dotMacCertificateRequest OBJECT IDENTIFIER ::=
 *		{ appleDotMacCertificate 1 }
 *      { 1 2 840 113635 100 3 1 }
 */
#define APPLE_DOTMAC_CERT_REQ_OID			APPLE_DOTMAC_CERT_OID, 1
#define APPLE_DOTMAC_CERT_REQ_OID_LENGTH	APPLE_DOTMAC_CERT_OID_LENGTH + 1

/*
 * Basis of .mac Certificate Extensions
 *
 * dotMacCertificateExtension OBJECT IDENTIFIER ::=
 *		{ appleDotMacCertificate 2 }
 *      { 1 2 840 113635 100 3 2 }
 */
#define APPLE_DOTMAC_CERT_EXTEN_OID			APPLE_DOTMAC_CERT_OID, 2
#define APPLE_DOTMAC_CERT_EXTEN_OID_LENGTH  APPLE_DOTMAC_CERT_OID_LENGTH + 1

/*
 * Basis of .mac Certificate request OID/value identifiers
 *
 * dotMacCertificateRequestValues OBJECT IDENTIFIER ::=
 *		{ appleDotMacCertificate 3 }
 *      { 1 2 840 113635 100 3 3 }
 */
#define APPLE_DOTMAC_CERT_REQ_VALUE_OID			APPLE_DOTMAC_CERT_OID, 3
#define APPLE_DOTMAC_CERT_REQ_VALUE_OID_LENGTH  APPLE_DOTMAC_CERT_OID_LENGTH + 1

/*
 * Basis of Apple-specific extended key usages
 *
 * appleExtendedKeyUsage OBJECT IDENTIFIER ::=
 *		{ appleDataSecurity 4 }
 *      { 1 2 840 113635 100 4 }
 */
#define APPLE_EKU_OID					APPLE_ADS_OID, 4
#define APPLE_EKU_OID_LENGTH			APPLE_ADS_OID_LENGTH + 1

/*
 * Basis of Apple Code Signing extended key usages
 * appleCodeSigning  OBJECT IDENTIFIER ::=
 *		{ appleExtendedKeyUsage 1 }
 *      { 1 2 840 113635 100 4 1 }
 */
#define APPLE_EKU_CODE_SIGNING			APPLE_EKU_OID, 1
#define APPLE_EKU_CODE_SIGNING_LENGTH	APPLE_EKU_OID_LENGTH + 1

/* -------------------------------------------------------------------------*/

/*
 * Basis of Apple-specific Certificate Policy identifiers
 * appleCertificatePolicies OBJECT IDENTIFIER ::=
 *		{ appleDataSecurity 5 }
 *		{ 1 2 840 113635 100 5 }
 */
#define APPLE_CERT_POLICIES				APPLE_ADS_OID, 5
#define APPLE_CERT_POLICIES_LENGTH		APPLE_ADS_OID_LENGTH + 1

/*
 * Base for MacAppStore Certificate Policy identifiers
 * macAppStoreCertificatePolicyIDs OBJECT IDENTIFIER ::=
 *		{ appleCertificatePolicies 6 }
 *		{ 1 2 840 113635 100 5 6 }
 */
#define APPLE_CERT_POLICIES_MACAPPSTORE		APPLE_CERT_POLICIES, 6
#define APPLE_CERT_POLICIES_MACAPPSTORE_LENGTH	APPLE_CERT_POLICIES_LENGTH + 1

/*
 * MacAppStore receipt verification Certificate Policy identifier
 * macAppStoreReceiptCertificatePolicyID OBJECT IDENTIFIER ::=
 *		{ appleCertificatePolicies 6 1 }
 *		{ 1 2 840 113635 100 5 6 1 }
 */
#define APPLE_CERT_POLICIES_MACAPPSTORE_RECEIPT		APPLE_CERT_POLICIES_MACAPPSTORE, 1
#define APPLE_CERT_POLICIES_MACAPPSTORE_RECEIPT_LENGTH	APPLE_CERT_POLICIES_MACAPPSTORE_LENGTH + 1

/*
 * Base for AppleID Certificate Policy identifiers
 * macAppStoreCertificatePolicyIDs OBJECT IDENTIFIER ::=
 *		{ appleCertificatePolicies 7 }
 *		{ 1 2 840 113635 100 5 7 }
 */
#define APPLE_CERT_POLICIES_APPLEID		APPLE_CERT_POLICIES, 7
#define APPLE_CERT_POLICIES_APPLEID_LENGTH	APPLE_CERT_POLICIES_LENGTH + 1

/*
 * AppleID Sharing Certificate Policy identifier
 * appleIDSharingPolicyID OBJECT IDENTIFIER ::=
 *		{ appleCertificatePolicies 7 1 }
 *		{ 1 2 840 113635 100 5 7 1 }
 */
#define APPLE_CERT_POLICIES_APPLEID_SHARING		APPLE_CERT_POLICIES_APPLEID, 1
#define APPLE_CERT_POLICIES_APPLEID_SHARING_LENGTH	APPLE_CERT_POLICIES_APPLEID_LENGTH + 1

/*
 * Apple Mobile Store Signing Policy identifier
 *
 * appleDemoContentReleaseSigningID ::= { appleCertificatePolicies 12}
 *     { 1 2 840 113635 100 5 12  }
 */
#define APPLE_CERT_POLICIES_MOBILE_STORE_SIGNING		APPLE_CERT_POLICIES, 12
#define APPLE_CERT_POLICIES_MOBILE_STORE_SIGNING_LENGTH	APPLE_CERT_POLICIES_LENGTH + 1

/*
 * Apple Test Mobile Store Signing Policy identifier
 *
 * appleDemoContentTestSigningID ::= { appleDemoContentReleaseSigningID 1}
 *     { 1 2 840 113635 100 5 12 1 }
 */
#define APPLE_CERT_POLICIES_TEST_MOBILE_STORE_SIGNING		APPLE_CERT_POLICIES, 12, 1
#define APPLE_CERT_POLICIES_TEST_MOBILE_STORE_SIGNING_LENGTH	APPLE_CERT_POLICIES_LENGTH + 2


/* -------------------------------------------------------------------------*/

/*
 * Basis of Apple-specific certificate extensions
 * appleCertificateExtensions OBJECT IDENTIFIER ::=
 *		{ appleDataSecurity 6 }
 *		{ 1 2 840 113635 100 6 }
 */
#define APPLE_EXTENSION_OID				APPLE_ADS_OID, 6
#define APPLE_EXTENSION_OID_LENGTH		APPLE_ADS_OID_LENGTH + 1

/*
 * Basis of Apple-specific Code Signing certificate extensions
 * appleCertificateExtensionCodeSigning OBJECT IDENTIFIER ::=
 *		{ appleCertificateExtensions 1 }
 *		{ 1 2 840 113635 100 6 1 }
 */
#define APPLE_EXTENSION_CODE_SIGNING		APPLE_EXTENSION_OID, 1
#define APPLE_EXTENSION_CODE_SIGNING_LENGTH	APPLE_EXTENSION_OID_LENGTH + 1

/*
 * Basis of MacAppStore receipt verification certificate extensions
 * macAppStoreReceiptExtension OBJECT IDENTIFIER ::=
 *             { appleCertificateExtensions 11 1 }
 *             { 1 2 840 113635 100 6 11 1 }
 */
#define APPLE_EXTENSION_MACAPPSTORE_RECEIPT            APPLE_EXTENSION_OID, 11, 1
#define APPLE_EXTENSION_MACAPPSTORE_RECEIPT_LENGTH     APPLE_EXTENSION_OID_LENGTH + 2

/*
 * Basis of Apple-specific Intermediate Certificate extensions
 * appleCertificateExtensionIntermediateMarker OBJECT IDENTIFIER ::=
 *		{ appleCertificateExtensions 2 }
 *		{ 1 2 840 113635 100 6 2 }
 */
#define APPLE_EXTENSION_INTERMEDIATE_MARKER         APPLE_EXTENSION_OID, 2
#define APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH	APPLE_EXTENSION_OID_LENGTH + 1

/*
 * Marker for the WWDR Intermediate Certificate
 * appleCertificateExtensionWWDRIntermediate OBJECT IDENTIFIER ::=
 *		{ appleCertificateExtensionIntermediateMarker 1 }
 *		{ 1 2 840 113635 100 6 2 1 }
 */
#define APPLE_EXTENSION_WWDR_INTERMEDIATE           APPLE_EXTENSION_INTERMEDIATE_MARKER, 1
#define APPLE_EXTENSION_WWDR_INTERMEDIATE_LENGTH    APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH  + 1

/*
 * Marker for the iTunes Store Intermediate Certificate
 * appleCertificateExtensioniTunesStoreIntermediate OBJECT IDENTIFIER ::=
 *		{ appleCertificateExtensionIntermediateMarker 2 }
 *		{ 1 2 840 113635 100 6 2 2 }
 */
#define APPLE_EXTENSION_ITMS_INTERMEDIATE           APPLE_EXTENSION_INTERMEDIATE_MARKER, 2
#define APPLE_EXTENSION_ITMS_INTERMEDIATE_LENGTH    APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH + 1

/*
 * Marker for the Application Integration Intermediate Certificate
 * appleCertificateExtensionApplicationIntegrationIntermediate OBJECT IDENTIFIER ::=
 *		{ appleCertificateExtensionIntermediateMarker 3 }
 *		{ 1 2 840 113635 100 6 2 3 }
 */
#define APPLE_EXTENSION_AAI_INTERMEDIATE           APPLE_EXTENSION_INTERMEDIATE_MARKER, 3
#define APPLE_EXTENSION_AAI_INTERMEDIATE_LENGTH    APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH + 1

/*
 *  Apple Apple ID Intermediate Marker (New subCA, no longer shared with push notification server cert issuer
 *
 *  appleCertificateExtensionAppleIDIntermediate ::=
 *    { appleCertificateExtensionIntermediateMarker 7 }
 *    { 1 2 840 113635 100 6 2 7 }
 *
 *  shared intermediate OID is APPLE_CERT_EXT_INTERMEDIATE_MARKER_APPLEID
 *  Apple Apple ID Intermediate Marker
 *  Same as APPLE_CERT_EXT_INTERMEDIATE_MARKER_APPLEID_2 on iOS
*/
#define APPLE_EXTENSION_APPLEID_INTERMEDIATE           APPLE_EXTENSION_INTERMEDIATE_MARKER, 7
#define APPLE_EXTENSION_APPLEID_INTERMEDIATE_LENGTH    APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH + 1

/*
 *  Apple System Integration 2 Intermediate Marker (New subCA)
 *
 *  appleCertificateExtensionSystemIntegration2Intermediate ::=
 *    { appleCertificateExtensionIntermediateMarker 10 }
 *    { 1 2 840 113635 100 6 2 10 }
*/
#define APPLE_EXTENSION_SYSINT2_INTERMEDIATE           APPLE_EXTENSION_INTERMEDIATE_MARKER, 10
#define APPLE_EXTENSION_SYSINT2_INTERMEDIATE_LENGTH    APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH + 1

/*
 *  Apple Developer Authentication Intermediate Marker (New subCA)
 *
 *  appleCertificateExtensionDeveloperAuthentication ::=
 *    { appleCertificateExtensionIntermediateMarker 11 }
 *    { 1 2 840 113635 100 6 2 11 }
*/
#define APPLE_EXTENSION_DEVELOPER_AUTHENTICATION        APPLE_EXTENSION_INTERMEDIATE_MARKER, 11
#define APPLE_EXTENSION_DEVELOPER_AUTHENTICATION_LENGTH APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH + 1

/*
 *  Apple Server Authentication Intermediate Marker (New subCA)
 *
 *  appleCertificateExtensionServerAuthentication ::=
 *    { appleCertificateExtensionIntermediateMarker 12 }
 *    { 1 2 840 113635 100 6 2 12 }
*/
#define APPLE_EXTENSION_SERVER_AUTHENTICATION           APPLE_EXTENSION_INTERMEDIATE_MARKER, 12
#define APPLE_EXTENSION_SERVER_AUTHENTICATION_LENGTH    APPLE_EXTENSION_INTERMEDIATE_MARKER_LENGTH + 1

/*
 *  Apple Secure Escrow Service Marker
 *
 *  appleEscrowService ::= { appleCertificateExtensions 23 1 }
 *    { 1 2 840 113635 100 6 23 1 }
 */
#define APPLE_EXTENSION_ESCROW_SERVICE                 APPLE_EXTENSION_OID, 23, 1
#define APPLE_EXTENSION_ESCROW_SERVICE_LENGTH          APPLE_EXTENSION_OID_LENGTH + 2

/*
 * Apple OS X Provisioning Profile Signing Marker
 * (note this is unfortunately under the EKU arc although it's used as a cert extension)
 */
#define APPLE_EXTENSION_PROVISIONING_PROFILE_SIGNING           APPLE_EKU_OID, 11
#define APPLE_EXTENSION_PROVISIONING_PROFILE_SIGNING_LENGTH    APPLE_EKU_OID_LENGTH + 1

/*
 * Marker for the AppleID Sharing Certificate
 * appleID OBJECT IDENTIFIER ::=
 *		{ appleExtendedKeyUsage 7}
 *		{ 1 2 840 113635 100 4 7 }
 */

#define APPLE_EXTENSION_APPLEID_SHARING				APPLE_EKU_OID, 7
#define APPLE_EXTENSION_APPLEID_SHARING_LENGTH		APPLE_EKU_OID_LENGTH + 1

/*
 * Netscape OIDs.
 */
#define NETSCAPE_BASE_OID		0x60, 0x86, 0x48, 0x01, 0x86, 0xf8, 0x42
#define NETSCAPE_BASE_OID_LEN   7

/*
 * Netscape cert extension.
 *
 *  netscape-cert-extension OBJECT IDENTIFIER ::=
 * 		{ 2 16 840 1 113730 1 }
 *
 *	BER = 06 08 60 86 48 01 86 F8 42 01
 */
#define NETSCAPE_CERT_EXTEN			NETSCAPE_BASE_OID, 0x01
#define NETSCAPE_CERT_EXTEN_LENGTH	NETSCAPE_BASE_OID_LEN + 1

#define NETSCAPE_CERT_POLICY		NETSCAPE_BASE_OID, 0x04
#define NETSCAPE_CERT_POLICY_LENGTH	NETSCAPE_BASE_OID_LEN + 1

/*
 * Domain Component OID
 */
#define OID_ITU_RFCDATA_2342 OID_ITU_RFCDATA, 0x49, 0x86
#define OID_ITU_RFCDATA_2342_LENGTH OID_ITU_RFCDATA_MEMBER_LENGTH + 2

#define OID_ITU_RFCDATA_2342_UCL OID_ITU_RFCDATA_2342, 0x49, 0x1F, 0x12, 0x8C
#define OID_ITU_RFCDATA_2342_UCL_LENGTH OID_ITU_RFCDATA_2342_LENGTH + 4

#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT 	OID_ITU_RFCDATA_2342_UCL, 0xE4
#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_LENGTH OID_ITU_RFCDATA_2342_UCL_LENGTH + 1

#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT, 0x81
#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES_LENGTH OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_LENGTH + 1

#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES_DOMAINCOMPONENT OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES, 0x99
#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES_DOMAINCOMPONENT_LENGTH OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES_LENGTH + 1

#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES_USERID OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES, 0x81
#define OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES_USERID_LENGTH OID_ITU_RFCDATA_2342_UCL_DIRECTORYPILOT_ATTRIBUTES_LENGTH + 1

#ifdef __cplusplus
}
#endif

#endif /* _OIDSBASE_H_ */
