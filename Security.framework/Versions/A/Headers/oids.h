/*
 * Copyright (c) 2005-2009,2011-2016 Apple Inc. All Rights Reserved.
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


/*
 * oids.h - declaration of OID consts
 *
 */

#ifndef	_LIB_DER_OIDS_H_
#define _LIB_DER_OIDS_H_

#include <stdint.h>
#include <string.h>

__BEGIN_DECLS

/*
 * Basic data types
 */
typedef uint8_t DERByte;
typedef size_t DERSize;

/*
 * Primary representation of a block of memory.
 */
typedef struct {
    DERByte		*data;
    DERSize		length;
} DERItem;

/* Algorithm oids. */
extern const DERItem
    oidRsa,             /* PKCS1 RSA encryption, used to identify RSA keys */
    oidMd2Rsa,          /* PKCS1 md2withRSAEncryption signature alg */
    oidMd4Rsa,          /* PKCS1 md4withRSAEncryption signature alg */
    oidMd5Rsa,          /* PKCS1 md5withRSAEncryption signature alg */
    oidSha1Rsa,         /* PKCS1 sha1withRSAEncryption signature alg */
    oidSha256Rsa,       /* PKCS1 sha256WithRSAEncryption signature alg */
    oidSha384Rsa,       /* PKCS1 sha384WithRSAEncryption signature alg */
    oidSha512Rsa,       /* PKCS1 sha512WithRSAEncryption signature alg */
    oidSha224Rsa,       /* PKCS1 sha224WithRSAEncryption signature alg */
    oidEcPubKey,        /* ECDH or ECDSA public key in a certificate */
    oidSha1Ecdsa,       /* ECDSA with SHA1 signature alg */
    oidSha224Ecdsa,     /* ECDSA with SHA224 signature alg */
    oidSha256Ecdsa,     /* ECDSA with SHA256 signature alg */
    oidSha384Ecdsa,     /* ECDSA with SHA384 signature alg */
    oidSha512Ecdsa,     /* ECDSA with SHA512 signature alg */
    oidSha1Dsa,         /* ANSI X9.57 DSA with SHA1 signature alg */
    oidMd2,             /* OID_RSA_HASH 2 */
    oidMd4,             /* OID_RSA_HASH 4 */
    oidMd5,             /* OID_RSA_HASH 5 */
    oidSha1,            /* OID_OIW_ALGORITHM 26 */
    oidSha1DsaOIW,      /* OID_OIW_ALGORITHM 27 */
    oidSha1DsaCommonOIW,/* OID_OIW_ALGORITHM 28 */
    oidSha1RsaOIW,      /* OID_OIW_ALGORITHM 29 */
    oidSha256,          /* OID_NIST_HASHALG 1 */
    oidSha384,          /* OID_NIST_HASHALG 2 */
    oidSha512,          /* OID_NIST_HASHALG 3 */
    oidSha224,          /* OID_NIST_HASHALG 4 */
    oidFee,             /* APPLE_ALG_OID 1 */
    oidMd5Fee,          /* APPLE_ALG_OID 3 */
    oidSha1Fee,         /* APPLE_ALG_OID 4 */
    oidEcPrime192v1,    /* OID_EC_CURVE 1 prime192v1/secp192r1/ansiX9p192r1*/
    oidEcPrime256v1,    /* OID_EC_CURVE 7 prime256v1/secp256r1*/
    oidAnsip384r1,      /* OID_CERTICOM_EC_CURVE 34 ansip384r1/secp384r1*/
    oidAnsip521r1;      /* OID_CERTICOM_EC_CURVE 35 ansip521r1/secp521r1*/

/* Standard X.509 Cert and CRL extensions. */
extern const DERItem
    oidSubjectKeyIdentifier,
    oidKeyUsage,
    oidPrivateKeyUsagePeriod,
    oidSubjectAltName,
    oidIssuerAltName,
    oidBasicConstraints,
    oidNameConstraints,
    oidCrlDistributionPoints,
    oidCertificatePolicies,
    oidAnyPolicy,
    oidPolicyMappings,
    oidAuthorityKeyIdentifier,
    oidPolicyConstraints,
    oidExtendedKeyUsage,
    oidAnyExtendedKeyUsage,
    oidInhibitAnyPolicy,
    oidAuthorityInfoAccess,
    oidSubjectInfoAccess,
    oidAdOCSP,
    oidAdCAIssuer,
    oidNetscapeCertType,
    oidEntrustVersInfo,
    oidMSNTPrincipalName;

/* Policy Qualifier IDs for Internet policy qualifiers. */
extern const DERItem
    oidQtCps,
    oidQtUNotice;

/* X.501 Name IDs. */
extern const DERItem
    oidCommonName,
    oidCountryName,
    oidLocalityName,
    oidStateOrProvinceName,
    oidOrganizationName,
    oidOrganizationalUnitName,
    oidDescription,
    oidEmailAddress,
    oidFriendlyName,
    oidLocalKeyId;

/* X.509 Extended Key Usages */
extern const DERItem
    oidExtendedKeyUsageServerAuth,
    oidExtendedKeyUsageClientAuth,
    oidExtendedKeyUsageCodeSigning,
    oidExtendedKeyUsageEmailProtection,
    oidExtendedKeyUsageTimeStamping,
    oidExtendedKeyUsageOCSPSigning,
    oidExtendedKeyUsageIPSec,
    oidExtendedKeyUsageMicrosoftSGC,
    oidExtendedKeyUsageNetscapeSGC;

/* Google Certificate Transparency OIDs */
extern const DERItem
    oidGoogleEmbeddedSignedCertificateTimestamp,
    oidGoogleOCSPSignedCertificateTimestamp;

__END_DECLS

#endif	/* _LIB_DER_OIDS_H_ */
