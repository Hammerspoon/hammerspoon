/*
 * Copyright (c) 2002-2011,2013 Apple Inc. All Rights Reserved.
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
	@header SecCertificate
	The functions provided in SecCertificate implement and manage a particular type of keychain item that represents a certificate.  You can store a certificate in a keychain, but a certificate can also be a transient object.
	
	You can use a certificate as a keychain item in most functions.
*/

#ifndef _SECURITY_SECCERTIFICATE_H_
#define _SECURITY_SECCERTIFICATE_H_

#define _SECURITY_VERSION_GREATER_THAN_57610_

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFData.h>
#include <CoreFoundation/CFDate.h>
#include <CoreFoundation/CFError.h>
#include <Security/SecBase.h>
#include <Security/cssmtype.h>
#include <Security/x509defs.h>
#include <Availability.h>
#include <AvailabilityMacros.h>
/*
#include <Security/SecTransform.h>
#include <Security/SecIdentity.h>
*/

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
	@enum CertificateItemAttributes
	@abstract Indicates the type of a certificate item attribute.
	@constant kSecSubjectItemAttr Indicates a DER-encoded subject distinguished name.
	@constant kSecIssuerItemAttr Indicates a DER-encoded issuer distinguished name.
	@constant kSecSerialNumberItemAttr Indicates a DER-encoded certificate serial number (without the tag and length).
	@constant kSecPublicKeyHashItemAttr Indicates a public key hash.
	@constant kSecSubjectKeyIdentifierItemAttr Indicates a subject key identifier.
	@constant kSecCertTypeItemAttr Indicates a certificate type.
	@constant kSecCertEncodingItemAttr Indicates a certificate encoding.
*/
enum
{
    kSecSubjectItemAttr 			 = 'subj',
    kSecIssuerItemAttr 				 = 'issu',
    kSecSerialNumberItemAttr     	 = 'snbr',
    kSecPublicKeyHashItemAttr    	 = 'hpky',
    kSecSubjectKeyIdentifierItemAttr = 'skid',
	kSecCertTypeItemAttr		 	 = 'ctyp',
	kSecCertEncodingItemAttr	 	 = 'cenc'
} /*DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER*/;

/*!
	@function SecCertificateGetTypeID
	@abstract Returns the type identifier of SecCertificate instances.
	@result The CFTypeID of SecCertificate instances.
*/
CFTypeID SecCertificateGetTypeID(void)
	__OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

#pragma mark ---- Certificate Operations ----

/*!
	@function SecCertificateCreateFromData
	@abstract Creates a certificate based on the input data, type, and encoding. 
    @param data A pointer to the certificate data.
    @param type The certificate type as defined in cssmtype.h.
    @param encoding The certificate encoding as defined in cssmtype.h.
	@param certificate On return, a reference to the newly created certificate.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated in 10.7  Please use the SecCertificateCreateWithData API instead.
*/
OSStatus SecCertificateCreateFromData(const CSSM_DATA *data, CSSM_CERT_TYPE type, CSSM_CERT_ENCODING encoding, SecCertificateRef * __nonnull CF_RETURNS_RETAINED certificate)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
	@function SecCertificateCreateWithData
	@abstract Create a certificate reference given its DER representation as a CFData.
    @param allocator CFAllocator to allocate the certificate data. Pass NULL to use the default allocator.
    @param data DER encoded X.509 certificate.
	@result On return, a reference to the certificate. Returns NULL if the passed-in data is not a valid DER-encoded X.509 certificate.
*/
__nullable
SecCertificateRef SecCertificateCreateWithData(CFAllocatorRef __nullable allocator, CFDataRef data)
	__OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_2_0);

/*!
	@function SecCertificateAddToKeychain
	@abstract Adds a certificate to the specified keychain.
    @param certificate A reference to a certificate.
    @param keychain A reference to the keychain in which to add the certificate. Pass NULL to add the certificate to the default keychain.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This function is successful only if the certificate was created using the SecCertificateCreateFromData or
	SecCertificateCreateWithData functions, and the certificate has not yet been added to the specified keychain.
*/
OSStatus SecCertificateAddToKeychain(SecCertificateRef certificate, SecKeychainRef __nullable keychain)
	__OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_NA);

/*!
	@function SecCertificateGetData
	@abstract Retrieves the data for a given certificate.
    @param certificate A reference to the certificate from which to retrieve the data.
    @param data On return, the CSSM_DATA structure pointed to by data is filled in. You must allocate the space for a CSSM_DATA structure before calling this function. This data pointer is only guaranteed to remain valid as long as the certificate remains unchanged and valid.
	@result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated in 10.7. Please use the SecCertificateCopyData API instead.
*/
OSStatus SecCertificateGetData(SecCertificateRef certificate, CSSM_DATA_PTR data)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
	@function SecCertificateCopyData
	@abstract Returns the DER representation of an X.509 certificate.
    @param certificate A reference to a certificate.
	@result On return, a data reference containing the DER encoded representation of the X.509 certificate.
 */
CFDataRef SecCertificateCopyData(SecCertificateRef certificate)
	__OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_2_0);

/*!
	@function SecCertificateGetType
	@abstract Retrieves the type for a given certificate.
    @param certificate A reference to the certificate from which to obtain the type.
    @param certificateType On return, the certificate type of the certificate. Certificate types are defined in cssmtype.h.
	@result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated in 10.7. Please use the SecCertificateCopyValues API instead. 
*/
OSStatus SecCertificateGetType(SecCertificateRef certificate, CSSM_CERT_TYPE *certificateType)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecCertificateGetSubject
    @abstract Retrieves the subject name for a given certificate.
    @param certificate A reference to the certificate from which to obtain the subject name.
    @param subject On return, a pointer to a CSSM_X509_NAME struct which contains the subject's X.509 name (x509defs.h). This pointer remains valid until the certificate reference is released. The caller should not attempt to free this pointer.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion Prior to Mac OS X 10.5, this function did not return any output in the subject parameter. Your code should check the returned pointer value (in addition to the function result) before attempting to use it.
        For example:
        const CSSM_X509_NAME *subject = NULL;
        OSStatus status = SecCertificateGetSubject(certificate, &subject);
        if ( (status == errSecSuccess) && (subject != NULL) ) {
            // subject is valid
        }
	   This API is deprecated in 10.7. Please use the SecCertificateCopyValues API instead. 
*/
OSStatus SecCertificateGetSubject(SecCertificateRef certificate, const CSSM_X509_NAME * __nullable * __nonnull subject)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecCertificateGetIssuer
    @abstract Retrieves the issuer name for a given certificate.
    @param certificate A reference to the certificate from which to obtain the issuer name.
    @param issuer On return, a pointer to a CSSM_X509_NAME struct which contains the issuer's X.509 name (x509defs.h). This pointer remains valid until the certificate reference is released. The caller should not attempt to free this pointer.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion Prior to Mac OS X 10.5, this function did not return any output in the issuer parameter. Your code should check the returned pointer value (in addition to the function result) before attempting to use it.
        For example:
        const CSSM_X509_NAME *issuer = NULL;
        OSStatus status = SecCertificateGetIssuer(certificate, &issuer);
        if ( (status == errSecSuccess) && (issuer != NULL) ) {
            // issuer is valid
        }
		This API is deprecated in 10.7. Please use the SecCertificateCopyValues API instead. 
*/
OSStatus SecCertificateGetIssuer(SecCertificateRef certificate, const CSSM_X509_NAME * __nullable * __nonnull issuer)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecCertificateGetCLHandle
    @abstract Retrieves the certificate library handle for a given certificate.
    @param certificate A reference to the certificate from which to obtain the certificate library handle.
    @param clHandle On return, the certificate library handle of the given certificate. This handle remains valid at least as long as the certificate does.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated in 10.7. Please use the SecCertificateCopyValues API instead.
*/
OSStatus SecCertificateGetCLHandle(SecCertificateRef certificate, CSSM_CL_HANDLE *clHandle)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecCertificateGetAlgorithmID
    @abstract Retrieves the algorithm identifier for a given certificate.
    @param certificate A reference to the certificate from which to retrieve the algorithm identifier.
    @param algid On return, a pointer to a CSSM_X509_ALGORITHM_IDENTIFIER struct which identifies the algorithm for this certificate (x509defs.h). This pointer remains valid until the certificate reference is released. The caller should not attempt to free this pointer.
    @result A result code. See "Security Error Codes" (SecBase.h).
	discussion This API is deprecated in 10.7. Please use the SecCertificateCopyValues API instead.
*/
OSStatus SecCertificateGetAlgorithmID(SecCertificateRef certificate, const CSSM_X509_ALGORITHM_IDENTIFIER * __nullable * __nonnull algid)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecCertificateCopyPublicKey
    @abstract Retrieves the public key for a given certificate.
    @param certificate A reference to the certificate from which to retrieve the public key.
    @param key On return, a reference to the public key for the specified certificate. Your code must release this reference by calling the CFRelease function.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecCertificateCopyPublicKey(SecCertificateRef certificate, SecKeyRef * __nonnull CF_RETURNS_RETAINED key)
	__OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_NA);

/*!
    @function SecCertificateCopyCommonName
    @abstract Retrieves the common name of the subject of a given certificate.
    @param certificate A reference to the certificate from which to retrieve the common name.
    @param commonName On return, a reference to the common name. Your code must release this reference by calling the CFRelease function.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion All the data in this string comes from the certificate itself, and thus it's in whatever language the certificate itself is in.
	Note that the certificate's common name field may not be present, or may be inadequate to describe the certificate; for display purposes,
	you should consider using SecCertificateCopySubjectSummary instead of this function.
*/
OSStatus SecCertificateCopyCommonName(SecCertificateRef certificate, CFStringRef * __nonnull CF_RETURNS_RETAINED commonName)
	__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_NA);

/*!
	@function SecCertificateCopySubjectSummary
	@abstract Returns a simple string which hopefully represents a human understandable summary.
    @param certificate  A reference to the certificate from which to derive the subject summary string.
	@result On return, a reference to the subject summary string. Your code must release this reference by calling the CFRelease function.
    @discussion All the data in this string comes from the certificate itself, and thus it's in whatever language the certificate itself is in.
*/
CFStringRef SecCertificateCopySubjectSummary(SecCertificateRef certificate)
	__OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_2_0);

/*!
    @function SecCertificateCopyEmailAddresses
    @abstract Returns an array of zero or more email addresses for the subject of a given certificate.
    @param certificate A reference to the certificate from which to retrieve the email addresses.
    @param emailAddresses On return, an array of zero or more CFStringRef elements corresponding to each email address found.
	Your code must release this array reference by calling the CFRelease function.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecCertificateCopyEmailAddresses(SecCertificateRef certificate, CFArrayRef * __nonnull CF_RETURNS_RETAINED emailAddresses)
	__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_NA);

/*!
    @function SecCertificateCopyPreference
    @abstract Returns the preferred certificate for the specified name and key usage. If a preferred certificate does not exist for the specified name and key usage, NULL is returned.
    @param name A string containing an email address (RFC822) or other name for which a preferred certificate is requested.
    @param keyUsage A CSSM_KEYUSE key usage value, as defined in cssmtype.h. Pass 0 to ignore this parameter.
    @param certificate On return, a reference to the preferred certificate, or NULL if none was found. You are responsible for releasing this reference by calling the CFRelease function.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function will typically be used to obtain the preferred encryption certificate for an email recipient.
	This API is deprecated in 10.7. Please use the SecCertificateCopyPreferred API instead.
*/
OSStatus SecCertificateCopyPreference(CFStringRef name, uint32 keyUsage, SecCertificateRef * __nonnull CF_RETURNS_RETAINED certificate)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecCertificateCopyPreferred
    @abstract Returns the preferred certificate for the specified name and key usage. If a preferred certificate does not exist for the specified name and key usage, NULL is returned.
    @param name A string containing an email address (RFC822) or other name for which a preferred certificate is requested.
    @param keyUsage A CFArrayRef value, containing items defined in SecItem.h  Pass NULL to ignore this parameter. (kSecAttrCanEncrypt, kSecAttrCanDecrypt, kSecAttrCanDerive, kSecAttrCanSign, kSecAttrCanVerify, kSecAttrCanWrap, kSecAttrCanUnwrap)
    @result On return, a reference to the preferred certificate, or NULL if none was found. You are responsible for releasing this reference by calling the CFRelease function.
    @discussion This function will typically be used to obtain the preferred encryption certificate for an email recipient. If a preferred certificate has not been set
	for the supplied name, the returned reference will be NULL. Your code should then perform a search for possible certificates, using the SecItemCopyMatching API.
 */
__nullable
SecCertificateRef SecCertificateCopyPreferred(CFStringRef name, CFArrayRef __nullable keyUsage)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function SecCertificateSetPreference
    @abstract Sets the preferred certificate for a specified name, key usage, and date.
    @param certificate A reference to the certificate which will be preferred.
    @param name A string containing an email address (RFC822) or other name for which a preferred certificate will be associated.
    @param keyUsage A CSSM_KEYUSE key usage value, as defined in cssmtype.h. Pass 0 to avoid specifying a particular key usage.
    @param date (optional) A date reference. If supplied, the preferred certificate will be changed only if this date is later than the currently saved setting. Pass NULL if this preference should not be restricted by date.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function will typically be used to set the preferred encryption certificate for an email recipient, either manually (when encrypting email to a recipient) or automatically upon receipt of encrypted email.
	This API is deprecated in 10.7. Plese use the SecCertificateSetPreferred API instead.
*/
OSStatus SecCertificateSetPreference(SecCertificateRef certificate, CFStringRef name, uint32 keyUsage, CFDateRef __nullable date)
	__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_NA);

/*!
    @function SecCertificateSetPreferred
    @abstract Sets the preferred certificate for a specified name and optional key usage.
    @param certificate A reference to the preferred certificate. If NULL is passed, any existing preference for the specified name is cleared instead.
    @param name A string containing an email address (RFC822) or other name for which a preferred certificate will be associated.
    @param keyUsage A CFArrayRef value, containing items defined in SecItem.h  Pass NULL to ignore this parameter. (kSecAttrCanEncrypt, kSecAttrCanDecrypt, kSecAttrCanDerive, kSecAttrCanSign, kSecAttrCanVerify, kSecAttrCanWrap, kSecAttrCanUnwrap)
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function will typically be used to set the preferred encryption certificate for an email recipient, either manually (when encrypting email to a recipient)
	or automatically upon receipt of encrypted email.
*/
OSStatus SecCertificateSetPreferred(SecCertificateRef __nullable certificate, CFStringRef name, CFArrayRef __nullable keyUsage)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
 @typedef SecKeyUsage
 @abstract Flags to indicate key usages in the KeyUsage extension of a certificate
 @constant kSecKeyUsageUnspecified No KeyUsage extension in certificate.
 @constant kSecKeyUsageDigitalSignature DigitalSignature bit set in KeyUsage extension.
 @constant kSecKeyUsageNonRepudiation NonRepudiation bit set in KeyUsage extension.
 @constant kSecKeyUsageContentCommitment ContentCommitment bit set in KeyUsage extension.
 @constant kSecKeyUsageKeyEncipherment KeyEncipherment bit set in KeyUsage extension.
 @constant kSecKeyUsageDataEncipherment DataEncipherment bit set in KeyUsage extension.
 @constant kSecKeyUsageKeyAgreement KeyAgreement bit set in KeyUsage extension.
 @constant kSecKeyUsageKeyCertSign KeyCertSign bit set in KeyUsage extension.
 @constant kSecKeyUsageCRLSign CRLSign bit set in KeyUsage extension.
 @constant kSecKeyUsageEncipherOnly EncipherOnly bit set in KeyUsage extension.
 @constant kSecKeyUsageDecipherOnly DecipherOnly bit set in KeyUsage extension.
 @constant kSecKeyUsageCritical KeyUsage extension is marked critical.
 @constant kSecKeyUsageAll For masking purposes, all SecKeyUsage values.
 */
typedef CF_OPTIONS(uint32_t, SecKeyUsage) {
    kSecKeyUsageUnspecified      = 0,
    kSecKeyUsageDigitalSignature = 1 << 0,
    kSecKeyUsageNonRepudiation   = 1 << 1,
    kSecKeyUsageContentCommitment= 1 << 1,
    kSecKeyUsageKeyEncipherment  = 1 << 2,
    kSecKeyUsageDataEncipherment = 1 << 3,
    kSecKeyUsageKeyAgreement     = 1 << 4,
    kSecKeyUsageKeyCertSign      = 1 << 5,
    kSecKeyUsageCRLSign          = 1 << 6,
    kSecKeyUsageEncipherOnly     = 1 << 7,
    kSecKeyUsageDecipherOnly     = 1 << 8,
    kSecKeyUsageCritical         = 1 << 31,
    kSecKeyUsageAll              = 0x7FFFFFFF
};

/*!
 @enum kSecPropertyKey
 @abstract Constants used to access dictionary entries returned by SecCertificateCopyValues
 @constant kSecPropertyKeyType The type of the entry
 @constant kSecPropertyKeyLabel The label of the entry
 @constant kSecPropertyKeyLocalizedLabel The localized label of the entry
 @constant kSecPropertyKeyValue The value of the entry
 */
	
extern const CFStringRef kSecPropertyKeyType __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyKeyLabel __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyKeyLocalizedLabel __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyKeyValue __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
	@enum kSecPropertyType
	@abstract Public Constants for property list values returned by SecCertificateCopyValues
	@discussion Note that kSecPropertyTypeTitle and kSecPropertyTypeError are defined in SecTrust.h
*/
extern const CFStringRef kSecPropertyTypeWarning __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyTypeSuccess __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyTypeSection __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyTypeData __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyTypeString __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyTypeURL __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecPropertyTypeDate __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function SecCertificateCopyValues
	@abstract		Creates a dictionary that represents a certificate's contents.
	@param certificate The certificate from which to get values
	@param keys		An array of string OID values, or NULL. If present, this is 
					the subset of values from the certificate to return. If NULL,
					all values will be returned. Only OIDs that are top level keys
					in the returned dictionary can be specified. Unknown OIDs are
					ignored.
	@param error	An optional pointer to a CFErrorRef. This value is 
					set if an error occurred.  If not NULL the caller is 
					responsible for releasing the CFErrorRef.
	@discussion		The keys array will contain all of the keys used in the
					returned dictionary. The top level keys in the returned
					dictionary are OIDs, many of which are found in SecCertificateOIDs.h.
					Each entry that is returned is itself a dictionary with four
					entries, whose keys are kSecPropertyKeyType, kSecPropertyKeyLabel, 
					kSecPropertyKeyLocalizedLabel, kSecPropertyKeyValue. The label
					entries may contain a descriptive (localized) string, or an
					OID string. The kSecPropertyKeyType describes the type in the
					value entry. The value entry may be any CFType, although it 
					is usually a CFStringRef, CFArrayRef or a CFDictionaryRef. 
*/
__nullable
CFDictionaryRef SecCertificateCopyValues(SecCertificateRef certificate, CFArrayRef __nullable keys, CFErrorRef *error)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @enum Transform  Key Value Constants
    @discussion 		Predefined values for the kSecTransformAttrCertificateUsage attribute.


	kSecCertificateUsageSigning
	kSecCertificateUsageSigningAndEncrypting
	kSecCertificateUsageDeriveAndSign
	
*/

extern const CFStringRef kSecCertificateUsageSigning __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecCertificateUsageSigningAndEncrypting __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
extern const CFStringRef kSecCertificateUsageDeriveAndSign __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function 			SecCertificateCopyLongDescription
	@abstract			Return the long description of a certificate
	@param alloc 		The CFAllocator which should be used to allocate
						memory for the dictionary and its storage for values. This
						parameter may be NULL in which case the current default
						CFAllocator is used. If this reference is not a valid
						CFAllocator, the behavior is undefined.
	@param certificate	The certificate from which to retrieve the long description
	@param	error		An optional pointer to a CFErrorRef. This value is 
						set if an error occurred.  If not NULL the caller is 
						responsible for releasing the CFErrorRef.
	@result				A CFStringRef of the long description or NULL. If NULL and the error
						parameter is supplied the error will be returned in the error parameter
	@discussion			Note that the format of this string may change in the future
*/

__nullable
CFStringRef SecCertificateCopyLongDescription(CFAllocatorRef __nullable alloc, SecCertificateRef certificate, CFErrorRef *error)
					__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function 			SecCertificateCopyShortDescription
	@abstract			Return the short description of a certificate
	@param alloc 		The CFAllocator which should be used to allocate
						memory for the dictionary and its storage for values. This
						parameter may be NULL in which case the current default
						CFAllocator is used. If this reference is not a valid
						CFAllocator, the behavior is undefined.
	@param certificate	The certificate from which to retrieve the short description
	@param	error		An optional pointer to a CFErrorRef. This value is 
						set if an error occurred.  If not NULL the caller is 
						responsible for releasing the CFErrorRef.
	@result				A CFStringRef of the short description or NULL. If NULL and the error
						parameter is supplied the error will be returned in the error parameter
 @discussion			Note that the format of this string may change in the future
*/

__nullable
CFStringRef SecCertificateCopyShortDescription(CFAllocatorRef __nullable alloc, SecCertificateRef certificate, CFErrorRef *error)
		__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function			SecCertificateCopySerialNumber
	@abstract			Return the certificate's serial number.
	@param certificate	The certificate from which to get values
	@param	error		An optional pointer to a CFErrorRef. This value is 
						set if an error occurred.  If not NULL the caller is 
						responsible for releasing the CFErrorRef.
	@discussion			Return the content of a DER-encoded integer (without the
						tag and length fields) for this certificate's serial 
						number.   The caller must CFRelease the value returned.
*/

__nullable
CFDataRef SecCertificateCopySerialNumber(SecCertificateRef certificate, CFErrorRef *error)
		__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function			SecCertificateCopyNormalizedIssuerContent
	@abstract			Return the certificate's normalized issuer
	@param certificate	The certificate from which to get values
	@param error		An optional pointer to a CFErrorRef. This value is 
						set if an error occurred.  If not NULL the caller is 
						responsible for releasing the CFErrorRef.
	@discussion			The issuer is a sequence in the format used by
						SecItemCopyMatching.  The content returned is a DER-encoded
						X.509 distinguished name. For a display version of the issuer,
						call SecCertificateCopyValues. The caller must CFRelease
						the value returned.
*/

__nullable
CFDataRef SecCertificateCopyNormalizedIssuerContent(SecCertificateRef certificate, CFErrorRef *error)
		__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function			SecCertificateCopyNormalizedSubjectContent
	@abstract			Return the certificate's normalized subject
	@param certificate	The certificate from which to get values
	@param error		An optional pointer to a CFErrorRef. This value is 
						set if an error occurred.  If not NULL the caller is 
						responsible for releasing the CFErrorRef.
	@discussion			The subject is a sequence in the format used by
						SecItemCopyMatching. The content returned is a DER-encoded
						X.509 distinguished name. For a display version of the subject,
						call SecCertificateCopyValues. The caller must CFRelease
						the value returned.
*/

__nullable
CFDataRef SecCertificateCopyNormalizedSubjectContent(SecCertificateRef certificate, CFErrorRef *error)
		__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECCERTIFICATE_H_ */
