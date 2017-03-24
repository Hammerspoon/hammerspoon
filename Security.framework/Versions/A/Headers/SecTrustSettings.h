/*
 * Copyright (c) 2006,2011,2014-2015 Apple Inc. All Rights Reserved.
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
 * SecTrustSettings.h - Public interface for manipulation of certificate 
 *						Trust Settings. 
 */
 
#ifndef	_SECURITY_SEC_TRUST_SETTINGS_H_
#define _SECURITY_SEC_TRUST_SETTINGS_H_

#include <CoreFoundation/CoreFoundation.h>
#include <Security/cssmtype.h>
#include <Security/SecKeychain.h>
#include <Security/SecPolicy.h>
#include <Security/SecCertificate.h>

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*
 * Any certificate (cert) which resides in a keychain can have associated with 
 * it a set of Trust Settings. Trust Settings specify conditions in which a 
 * given cert can be trusted or explicitly distrusted. A "trusted" cert is
 * either a root (self-signed) cert that, when a cert chain verifies back to that
 * root, the entire cert chain is trusted; or a non-root cert that does not need 
 * to verify to a trusted root cert (which is normally the case when verifying a 
 * cert chain). An "explicitly distrusted" cert is one which will, when encountered 
 * during the evaluation of a cert chain, cause immediate and unconditional failure 
 * of the verify operation. 
 * 
 * Trust Settings are configurable by the user; they can apply on three levels
 * (called domains):
 *
 * -- Per-user.
 * -- Locally administered, system-wide. Administrator privileges are required
 *    to make changes to this domain.
 * -- System. These Trust Settings are immutable and comprise the set of trusted
 *    root certificates supplied in Mac OS X. 
 *
 * Per-user Trust Settings override locally administered Trust Settings, which 
 * in turn override the System Trust Settings. 
 *
 * Each cert's Trust Settings are expressed as a CFArray which includes any 
 * number (including zero) of CFDictionaries, each of which comprises one set of
 * Usage Constraints. Each Usage Constraints dictionary contains zero or one of 
 * each the following components:
 *
 * key = kSecTrustSettingsPolicy		value = SecPolicyRef
 * key = kSecTrustSettingsApplication	value = SecTrustedApplicationRef
 * key = kSecTrustSettingsPolicyString	value = CFString, policy-specific
 * key = kSecTrustSettingsKeyUsage		value = CFNumber, an SInt32 key usage
 * 
 * A given Usage Constraints dictionary applies to a given cert if *all* of the 
 * usage constraint components specified in the dictionary match the usage of 
 * the cert being evaluated; when this occurs, the value of the 
 * kSecTrustSettingsResult entry in the dictionary, shown below, is the effective
 * trust setting for the cert. 
 *
 * key = kSecTrustSettingsResult		value = CFNumber, an SInt32 SecTrustSettingsResult
 *
 * The overall Trust Settings of a given cert are the sum of all such Usage 
 * Constraints CFDictionaries: Trust Settings for a given usage apply if *any* 
 * of the CFDictionaries in the cert's Trust Settings array satisfies
 * the specified usage. Thus, when a cert has multiple Usage Constraints 
 * dictionaries in its Trust Settings array, the overall Trust Settings
 * for the cert are
 *
 * (Usage Constraint 0 component 0 AND Usage Constraint 0 component 1 ...)
 *     -- OR --
 * (Usage Constraint 1 component 0 AND Usage Constraint 1 component 1 ...)
 *     -- OR --
 * ...
 *
 * Notes on the various Usage Constraints components:
 *
 * kSecTrustSettingsPolicy			Specifies a cert verification policy, e.g., SSL, 
 *									SMIME, etc.
 * kSecTrustSettingsApplication 	Specifies the application performing the cert 
 *									verification.
 * kSecTrustSettingsPolicyString 	Policy-specific. For the SMIME policy, this is 
 *									an email address. 
 *									For the SSL policy, this is a host name.
 * kSecTrustSettingsKeyUsage		A bitfield indicating key operations (sign, 
 *									encrypt, etc.) for which this Usage Constraint 
 *									apply. Values are defined below as the 
 *									SecTrustSettingsKeyUsage enum. 
 * kSecTrustSettingsResult			The resulting trust value. If not present this has a
 *									default of kSecTrustSettingsResultTrustRoot, meaning 
 *								 	"trust this root cert". Other legal values are:
 *									kSecTrustSettingsResultTrustAsRoot : trust non-root
 *										cert as if it were a trusted root. 
 *									kSecTrustSettingsResultDeny : explicitly distrust this
 *										cert. 
 *									kSecTrustSettingsResultUnspecified : neither trust nor
 *										distrust; can be used to specify an "Allowed error" 
 *										(see below) without assigning trust to a specific 
 *										cert. 
 *
 * Another optional component in a Usage Constraints dictionary is a CSSM_RETURN
 * which, if encountered during certificate verification, is ignored for that
 * cert. These "allowed error" values are constrained by Usage Constraints as
 * described above; a Usage Constraint dictionary with no constraints but with
 * an Allowed Error value causes that error to always be allowed when the cert
 * is being evaluated.
 *
 * The "allowed error" entry in a Usage Constraints dictionary is formatted 
 * as follows:
 * 
 * key = kSecTrustSettingsAllowedError	value = CFNumber, an SInt32 CSSM_RETURN 
 *
 * Note that if kSecTrustSettingsResult value of kSecTrustSettingsResultUnspecified
 * is *not* present for a Usage Constraints dictionary with no Usage 
 * Constraints, the default of kSecTrustSettingsResultTrustRoot is assumed. To 
 * specify a kSecTrustSettingsAllowedError without explicitly trusting (or 
 * distrusting) the associated cert, specify kSecTrustSettingsResultUnspecified 
 * for the kSecTrustSettingsResult component. 
 *
 * Note that an empty Trust Settings array means "always trust this cert, 
 * with a resulting kSecTrustSettingsResult of kSecTrustSettingsResultTrustRoot". 
 * An empty Trust Settings array is definitely not the same as *no* Trust 
 * Settings, which means "this cert must be verified to a known trusted cert". 
 *
 * Note the distinction between kSecTrustSettingsResultTrustRoot and
 * kSecTrustSettingsResultTrustAsRoot; the former can only be applied to 
 * root (self-signed) certs; the latter can only be applied to non-root 
 * certs. This also means that an empty TrustSettings array for a non-root
 * cert is invalid, since the default value for kSecTrustSettingsResult is
 * kSecTrustSettingsResultTrustRoot, which is invalid for a non-root cert. 
 *
 * Authentication
 * --------------
 * 
 * When making changes to the per-user Trust Settings, the user will be 
 * prompted with an alert panel asking for authentication via user name a 
 * password (or other credentials normally used for login). This means 
 * that it is not possible to modify per-user Trust Settings when not 
 * running in a GUI environment (i.e. the user is not logged in via 
 * Loginwindow). 
 * 
 * When making changes to the system-wide Trust Settings, the user will be 
 * prompted with an alert panel asking for an administrator's name and 
 * password, unless the calling process is running as root in which case
 * no futher authentication is needed.
 */
 
/*
 * The keys in one Usage Constraints dictionary.
 */
#define kSecTrustSettingsPolicy			CFSTR("kSecTrustSettingsPolicy")
#define kSecTrustSettingsApplication	CFSTR("kSecTrustSettingsApplication")
#define kSecTrustSettingsPolicyString	CFSTR("kSecTrustSettingsPolicyString")
#define kSecTrustSettingsKeyUsage		CFSTR("kSecTrustSettingsKeyUsage")
#define kSecTrustSettingsAllowedError	CFSTR("kSecTrustSettingsAllowedError")
#define kSecTrustSettingsResult			CFSTR("kSecTrustSettingsResult")

/* 
 * Key usage bits, the value for Usage Constraints key kSecTrustSettingsKeyUsage.
 */
typedef CF_OPTIONS(uint32, SecTrustSettingsKeyUsage) {
	/* sign/verify data */
	kSecTrustSettingsKeyUseSignature		= 0x00000001,	
	/* bulk encryption */
	kSecTrustSettingsKeyUseEnDecryptData	= 0x00000002,	
	/* key wrap/unwrap */
	kSecTrustSettingsKeyUseEnDecryptKey		= 0x00000004,	
	/* sign/verify cert */
	kSecTrustSettingsKeyUseSignCert			= 0x00000008,	
	/* sign/verify CRL and OCSP */
	kSecTrustSettingsKeyUseSignRevocation	= 0x00000010,	
	/* key exchange, e.g., Diffie-Hellman */
	kSecTrustSettingsKeyUseKeyExchange		= 0x00000020,	
	/* any usage (the default if this value is not specified) */
	kSecTrustSettingsKeyUseAny				= 0xffffffff	
};

/*
 * The effective Trust Setting result.
 */
typedef CF_ENUM(uint32, SecTrustSettingsResult) {
	kSecTrustSettingsResultInvalid = 0,		/* Never valid in a Trust Settings array or 
											 * in an API call. */
	kSecTrustSettingsResultTrustRoot,		/* Root cert is explicitly trusted */
	kSecTrustSettingsResultTrustAsRoot,		/* Non-root cert is explicitly trusted */
	kSecTrustSettingsResultDeny,			/* Cert is explicitly distrusted */
	kSecTrustSettingsResultUnspecified		/* Neither trusted nor distrusted; evaluation
											 * proceeds as usual */
};

/* 
 * Specify user, local administrator, or system domain Trust Settings. 
 * Note that kSecTrustSettingsDomainSystem settings are read-only, even by
 * root.  
 */
typedef CF_ENUM(uint32, SecTrustSettingsDomain) {
	kSecTrustSettingsDomainUser = 0,
	kSecTrustSettingsDomainAdmin,
	kSecTrustSettingsDomainSystem
};

/*
 * SecCertificateRef value indicating the default Root Certificate Trust Settings 
 * for a given domain. When evaluating Trust Settings for a root cert in 
 * a given domain, *and* no matching explicit Trust Settings exists for the 
 * root cert in questions, *and* default Root Cert Trust Settings exist
 * in that domain which matches the evaluation condition, then the 
 * SecTrustSettingsResult for that default Trust Setting (if not 
 * kSecTrustSettingsResultUnspecified) will apply. 
 *
 * This can be used e.g. by a system administrator to explicitly distrust all
 * of the root certs in the (immutable) system domain for a specific policy. 
 *
 * This const is passed as the 'SecCertificateRef certRef' argument to 
 * SecTrustSettingsCopyTrustSettings(), SecTrustSettingsSetTrustSettings(),
 * and SecTrustSettingsRemoveTrustSettings(), and 
 * SecTrustSettingsCopyModificationDate(). 
 */
#define kSecTrustSettingsDefaultRootCertSetting		((SecCertificateRef)-1)

/* 
 * Obtain Trust Settings for specified cert.
 * Caller must CFRelease() the returned CFArray. 
 * Returns errSecItemNotFound if no Trust settings exist for the cert.
 */
OSStatus SecTrustSettingsCopyTrustSettings(
	SecCertificateRef		certRef, 
	SecTrustSettingsDomain	domain,	
	CFArrayRef * __nonnull CF_RETURNS_RETAINED trustSettings);	/* RETURNED */

/* 
 * Specify Trust Settings for specified cert. If specified cert
 * already has Trust Settings in the specified domain, they will 
 * be replaced.
 * The trustSettingsDictOrArray parameter is either a CFDictionary,
 * a CFArray of them, or NULL. NULL indicates "always trust this 
 * root cert regardless of usage". 
 */
OSStatus SecTrustSettingsSetTrustSettings(
	SecCertificateRef		certRef, 
	SecTrustSettingsDomain	domain,	
	CFTypeRef __nullable	trustSettingsDictOrArray);

/*
 * Delete Trust Settings for specified cert. 
 * Returns errSecItemNotFound if no Trust settings exist for the cert.
 */
OSStatus SecTrustSettingsRemoveTrustSettings(
	SecCertificateRef		certRef, 
	SecTrustSettingsDomain	domain);	

/* 
 * Obtain an array of all certs which have Trust Settings in the 
 * specified domain. Elements in the returned certArray are
 * SecCertificateRefs. 
 * Caller must CFRelease() the returned array.
 * Returns errSecNoTrustSettings if no trust settings exist
 * for the specified domain. 
 */
OSStatus SecTrustSettingsCopyCertificates(
	SecTrustSettingsDomain	domain,		
	CFArrayRef * __nullable CF_RETURNS_RETAINED certArray);

/* 
 * Obtain the time at which a specified cert's Trust Settings
 * were last modified. Caller must CFRelease the result. 
 * Returns errSecItemNotFound if no Trust Settings exist for specified 
 * cert and domain. 
 */
OSStatus SecTrustSettingsCopyModificationDate(
	SecCertificateRef		certRef, 
	SecTrustSettingsDomain	domain,
	CFDateRef * __nonnull CF_RETURNS_RETAINED modificationDate);	/* RETURNED */

/*
 * Obtain an external, portable representation of the specified 
 * domain's TrustSettings. Caller must CFRelease the returned data. 
 * Returns errSecNoTrustSettings if no trust settings exist
 * for the specified domain. 
 */
OSStatus SecTrustSettingsCreateExternalRepresentation(
	SecTrustSettingsDomain	domain,
	CFDataRef * __nonnull CF_RETURNS_RETAINED trustSettings);

/*
 * Import trust settings, obtained via SecTrustSettingsCreateExternalRepresentation,
 * into the specified domain. 
 */
OSStatus SecTrustSettingsImportExternalRepresentation(
	SecTrustSettingsDomain	domain,
	CFDataRef				trustSettings);

CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif	/* _SECURITY_SEC_TRUST_SETTINGS_H_ */

