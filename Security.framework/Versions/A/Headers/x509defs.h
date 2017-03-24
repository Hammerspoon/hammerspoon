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
 * x509defs.h -- Data structures for X509 Certificate Library field values
 */

#ifndef _X509DEFS_H_
#define _X509DEFS_H_  1

#include <Security/cssmtype.h>

#ifdef __cplusplus
extern "C" {
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef uint8 CSSM_BER_TAG;
#define BER_TAG_UNKNOWN 0
#define BER_TAG_BOOLEAN 1
#define BER_TAG_INTEGER 2
#define BER_TAG_BIT_STRING 3
#define BER_TAG_OCTET_STRING 4
#define BER_TAG_NULL 5
#define BER_TAG_OID 6
#define BER_TAG_OBJECT_DESCRIPTOR 7
#define BER_TAG_EXTERNAL 8
#define BER_TAG_REAL 9
#define BER_TAG_ENUMERATED 10
/* 12 to 15 are reserved for future versions of the recommendation */
#define BER_TAG_PKIX_UTF8_STRING 12
#define BER_TAG_SEQUENCE 16
#define BER_TAG_SET 17
#define BER_TAG_NUMERIC_STRING 18
#define BER_TAG_PRINTABLE_STRING 19
#define BER_TAG_T61_STRING 20
#define BER_TAG_TELETEX_STRING BER_TAG_T61_STRING
#define BER_TAG_VIDEOTEX_STRING 21
#define BER_TAG_IA5_STRING 22
#define BER_TAG_UTC_TIME 23
#define BER_TAG_GENERALIZED_TIME 24
#define BER_TAG_GRAPHIC_STRING 25
#define BER_TAG_ISO646_STRING 26
#define BER_TAG_GENERAL_STRING 27
#define BER_TAG_VISIBLE_STRING BER_TAG_ISO646_STRING
/* 28 - are reserved for future versions of the recommendation */
#define BER_TAG_PKIX_UNIVERSAL_STRING 28
#define BER_TAG_PKIX_BMP_STRING 30


/* Data Structures for X.509 Certificates */

typedef struct cssm_x509_algorithm_identifier {
    CSSM_OID algorithm;
    CSSM_DATA parameters;
} CSSM_X509_ALGORITHM_IDENTIFIER DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_ALGORITHM_IDENTIFIER_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* X509 Distinguished name structure */
typedef struct cssm_x509_type_value_pair {
    CSSM_OID type;
    CSSM_BER_TAG valueType; /* The Tag to be used when */
    /*this value is BER encoded */
    CSSM_DATA value;
} CSSM_X509_TYPE_VALUE_PAIR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_TYPE_VALUE_PAIR_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509_rdn {
    uint32 numberOfPairs;
    CSSM_X509_TYPE_VALUE_PAIR_PTR AttributeTypeAndValue;
} CSSM_X509_RDN DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_RDN_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509_name {
    uint32 numberOfRDNs;
    CSSM_X509_RDN_PTR RelativeDistinguishedName;
} CSSM_X509_NAME DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_NAME_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* Public key info struct */
typedef struct cssm_x509_subject_public_key_info {
    CSSM_X509_ALGORITHM_IDENTIFIER algorithm;
    CSSM_DATA subjectPublicKey;
} CSSM_X509_SUBJECT_PUBLIC_KEY_INFO DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_SUBJECT_PUBLIC_KEY_INFO_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509_time {
    CSSM_BER_TAG timeType;
    CSSM_DATA time;
} CSSM_X509_TIME DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_TIME_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* Validity struct */
typedef struct x509_validity {
    CSSM_X509_TIME notBefore;
    CSSM_X509_TIME notAfter;
} CSSM_X509_VALIDITY DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_VALIDITY_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#define CSSM_X509_OPTION_PRESENT CSSM_TRUE
#define CSSM_X509_OPTION_NOT_PRESENT CSSM_FALSE
typedef CSSM_BOOL CSSM_X509_OPTION;

typedef struct cssm_x509ext_basicConstraints {
    CSSM_BOOL cA;
    CSSM_X509_OPTION pathLenConstraintPresent;
    uint32 pathLenConstraint;
} CSSM_X509EXT_BASICCONSTRAINTS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509EXT_BASICCONSTRAINTS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef enum extension_data_format {
    CSSM_X509_DATAFORMAT_ENCODED = 0,
    CSSM_X509_DATAFORMAT_PARSED,
    CSSM_X509_DATAFORMAT_PAIR
} CSSM_X509EXT_DATA_FORMAT;

typedef struct cssm_x509_extensionTagAndValue {
    CSSM_BER_TAG type;
    CSSM_DATA value;
} CSSM_X509EXT_TAGandVALUE DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509EXT_TAGandVALUE_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509ext_pair {
    CSSM_X509EXT_TAGandVALUE tagAndValue;
    void *parsedValue;
} CSSM_X509EXT_PAIR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509EXT_PAIR_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* Extension structure */
typedef struct cssm_x509_extension {
    CSSM_OID extnId;
    CSSM_BOOL critical;
    CSSM_X509EXT_DATA_FORMAT format;
    union cssm_x509ext_value {
        CSSM_X509EXT_TAGandVALUE *tagAndValue;
        void *parsedValue;
        CSSM_X509EXT_PAIR *valuePair;
    } value;
    CSSM_DATA BERvalue;
} CSSM_X509_EXTENSION DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_EXTENSION_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509_extensions {
    uint32 numberOfExtensions;
    CSSM_X509_EXTENSION_PTR extensions;
} CSSM_X509_EXTENSIONS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_EXTENSIONS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* X509V3 certificate structure */
typedef struct cssm_x509_tbs_certificate {
    CSSM_DATA version;
    CSSM_DATA serialNumber;
    CSSM_X509_ALGORITHM_IDENTIFIER signature;
    CSSM_X509_NAME issuer;
    CSSM_X509_VALIDITY validity;
    CSSM_X509_NAME subject;
    CSSM_X509_SUBJECT_PUBLIC_KEY_INFO subjectPublicKeyInfo;
    CSSM_DATA issuerUniqueIdentifier;
    CSSM_DATA subjectUniqueIdentifier;
    CSSM_X509_EXTENSIONS extensions;
} CSSM_X509_TBS_CERTIFICATE DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_TBS_CERTIFICATE_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* Signature structure */
typedef struct cssm_x509_signature {
    CSSM_X509_ALGORITHM_IDENTIFIER algorithmIdentifier;
    CSSM_DATA encrypted;
} CSSM_X509_SIGNATURE DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_SIGNATURE_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* Signed certificate structure */
typedef struct cssm_x509_signed_certificate {
    CSSM_X509_TBS_CERTIFICATE certificate;
    CSSM_X509_SIGNATURE signature;
} CSSM_X509_SIGNED_CERTIFICATE DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_SIGNED_CERTIFICATE_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509ext_policyQualifierInfo {
    CSSM_OID policyQualifierId;
    CSSM_DATA value;
} CSSM_X509EXT_POLICYQUALIFIERINFO DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509EXT_POLICYQUALIFIERINFO_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509ext_policyQualifiers {
    uint32 numberOfPolicyQualifiers;
    CSSM_X509EXT_POLICYQUALIFIERINFO *policyQualifier;
} CSSM_X509EXT_POLICYQUALIFIERS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509EXT_POLICYQUALIFIERS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509ext_policyInfo {
    CSSM_OID policyIdentifier;
    CSSM_X509EXT_POLICYQUALIFIERS policyQualifiers;
} CSSM_X509EXT_POLICYINFO DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509EXT_POLICYINFO_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* Data Structures for X.509 Certificate Revocations Lists */

/* x509V2 entry in the CRL revokedCertificates sequence */
typedef struct cssm_x509_revoked_cert_entry {
    CSSM_DATA certificateSerialNumber;
    CSSM_X509_TIME revocationDate;
    CSSM_X509_EXTENSIONS extensions;
} CSSM_X509_REVOKED_CERT_ENTRY DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_REVOKED_CERT_ENTRY_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509_revoked_cert_list {
    uint32 numberOfRevokedCertEntries;
    CSSM_X509_REVOKED_CERT_ENTRY_PTR revokedCertEntry;
} CSSM_X509_REVOKED_CERT_LIST DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_REVOKED_CERT_LIST_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/* x509v2 Certificate Revocation List (CRL) (unsigned) structure */
typedef struct cssm_x509_tbs_certlist {
    CSSM_DATA version;
    CSSM_X509_ALGORITHM_IDENTIFIER signature;
    CSSM_X509_NAME issuer;
    CSSM_X509_TIME thisUpdate;
    CSSM_X509_TIME nextUpdate;
    CSSM_X509_REVOKED_CERT_LIST_PTR revokedCertificates;
    CSSM_X509_EXTENSIONS extensions;
} CSSM_X509_TBS_CERTLIST DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_TBS_CERTLIST_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

typedef struct cssm_x509_signed_crl {
    CSSM_X509_TBS_CERTLIST tbsCertList;
    CSSM_X509_SIGNATURE signature;
} CSSM_X509_SIGNED_CRL DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_X509_SIGNED_CRL_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#pragma clang diagnostic pop

#ifdef __cplusplus
}
#endif

#endif /* _X509DEFS_H_ */
