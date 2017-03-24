/*
 * Copyright (c) 2002-2014 Apple Inc. All Rights Reserved.
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
	@header SecKey
	The functions provided in SecKey.h implement and manage a particular
    type of keychain item that represents a key.  A key can be stored in a
    keychain, but a key can also be a transient object.

	You can use a key as a keychain item in most functions.
*/

#ifndef _SECURITY_SECKEY_H_
#define _SECURITY_SECKEY_H_

#include <dispatch/dispatch.h>
#include <Security/SecBase.h>
#include <Security/SecAccess.h>
#include <Security/cssmtype.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFSet.h>
#include <sys/types.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
	@enum KeyItemAttributeConstants
	@abstract Specifies keychain item attributes for keys.
    @constant kSecKeyKeyClass type uint32 (CSSM_KEYCLASS), value
    is one of CSSM_KEYCLASS_PUBLIC_KEY, CSSM_KEYCLASS_PRIVATE_KEY
    or CSSM_KEYCLASS_SESSION_KEY.
    @constant kSecKeyPrintName type blob, human readable name of
    the key.  Same as kSecLabelItemAttr for normal keychain items.
    @constant kSecKeyAlias type blob, currently unused.
    @constant kSecKeyPermanent type uint32, value is nonzero iff
    this key is permanent (stored in some keychain).  This is always
    1.
    @constant kSecKeyPrivate type uint32, value is nonzero iff this
    key is protected by a user login or a password, or both.
    @constant kSecKeyModifiable type uint32, value is nonzero iff
    attributes of this key can be modified.
    @constant kSecKeyLabel type blob, for private and public keys
    this contains the hash of the public key.  This is used to
    associate certificates and keys.  Its value matches the value
    of the kSecPublicKeyHashItemAttr of a certificate and it's used
    to construct an identity from a certificate and a key.
    For symmetric keys this is whatever the creator of the key
    passed in during the generate key call.
    @constant kSecKeyApplicationTag type blob, currently unused.
    @constant kSecKeyKeyCreator type data, the data points to a
    CSSM_GUID structure representing the moduleid of the csp owning
    this key.
    @constant kSecKeyKeyType type uint32, value is a CSSM_ALGORITHMS
    representing the algorithm associated with this key.
    @constant kSecKeyKeySizeInBits type uint32, value is the number
    of bits in this key.
    @constant kSecKeyEffectiveKeySize type uint32, value is the
    effective number of bits in this key.  For example a des key
    has a kSecKeyKeySizeInBits of 64 but a kSecKeyEffectiveKeySize
    of 56.
    @constant kSecKeyStartDate type CSSM_DATE.  Earliest date from
    which this key may be used.  If the value is all zeros or not
    present, no restriction applies.
    @constant kSecKeyEndDate type CSSM_DATE.  Latest date at
    which this key may be used.  If the value is all zeros or not
    present, no restriction applies.
    @constant kSecKeySensitive type uint32, iff value is nonzero
    this key cannot be wrapped with CSSM_ALGID_NONE.
    @constant kSecKeyAlwaysSensitive type uint32, value is nonzero
    iff this key has always been marked sensitive.
    @constant kSecKeyExtractable type uint32, value is nonzero iff
    this key can be wrapped.
    @constant kSecKeyNeverExtractable type uint32, value is nonzero
    iff this key was never marked extractable.
    @constant kSecKeyEncrypt type uint32, value is nonzero iff this
    key can be used in an encrypt operation.
    @constant kSecKeyDecrypt type uint32, value is nonzero iff this
    key can be used in a decrypt operation.
    @constant kSecKeyDerive type uint32, value is nonzero iff this
    key can be used in a deriveKey operation.
    @constant kSecKeySign type uint32, value is nonzero iff this
    key can be used in a sign operation.
    @constant kSecKeyVerify type uint32, value is nonzero iff this
    key can be used in a verify operation.
    @constant kSecKeySignRecover type uint32.
    @constant kSecKeyVerifyRecover type uint32.
    key can unwrap other keys.
    @constant kSecKeyWrap type uint32, value is nonzero iff this
    key can wrap other keys.
    @constant kSecKeyUnwrap type uint32, value is nonzero iff this
    key can unwrap other keys.
	@discussion
	The use of these enumerations has been deprecated.  Please
	use the equivalent items defined in SecItem.h
	@@@.
*/
CF_ENUM(int)
{
    kSecKeyKeyClass =          0,
    kSecKeyPrintName =         1,
    kSecKeyAlias =             2,
    kSecKeyPermanent =         3,
    kSecKeyPrivate =           4,
    kSecKeyModifiable =        5,
    kSecKeyLabel =             6,
    kSecKeyApplicationTag =    7,
    kSecKeyKeyCreator =        8,
    kSecKeyKeyType =           9,
    kSecKeyKeySizeInBits =    10,
    kSecKeyEffectiveKeySize = 11,
    kSecKeyStartDate =        12,
    kSecKeyEndDate =          13,
    kSecKeySensitive =        14,
    kSecKeyAlwaysSensitive =  15,
    kSecKeyExtractable =      16,
    kSecKeyNeverExtractable = 17,
    kSecKeyEncrypt =          18,
    kSecKeyDecrypt =          19,
    kSecKeyDerive =           20,
    kSecKeySign =             21,
    kSecKeyVerify =           22,
    kSecKeySignRecover =      23,
    kSecKeyVerifyRecover =    24,
    kSecKeyWrap =             25,
    kSecKeyUnwrap =           26
};

    /*!
    @enum SecCredentialType
    @abstract Determines the type of credential returned by SecKeyGetCredentials.
    @constant kSecCredentialTypeWithUI Operations with this key are allowed to present UI if required.
    @constant kSecCredentialTypeNoUI Operations with this key are not allowed to present UI, and will fail if UI is required.
    @constant kSecCredentialTypeDefault The default setting for determining whether to present UI is used. This setting can be changed with a call to SecKeychainSetUserInteractionAllowed.
*/
typedef CF_ENUM(uint32, SecCredentialType)
{
	kSecCredentialTypeDefault = 0,
	kSecCredentialTypeWithUI,
	kSecCredentialTypeNoUI
};

/*!
    @typedef SecPadding
    @abstract Supported padding types.
*/
typedef CF_ENUM(uint32_t, SecPadding)
{
    kSecPaddingNone      = 0,
    kSecPaddingPKCS1     = 1,

    /* For SecKeyRawSign/SecKeyRawVerify only,
     ECDSA signature is raw byte format {r,s}, big endian.
     First half is r, second half is s */
    kSecPaddingSigRaw  = 0x4000,

    /* For SecKeyRawSign/SecKeyRawVerify only, data to be signed is an MD2
       hash; standard ASN.1 padding will be done, as well as PKCS1 padding
       of the underlying RSA operation. */
    kSecPaddingPKCS1MD2  = 0x8000,

    /* For SecKeyRawSign/SecKeyRawVerify only, data to be signed is an MD5
       hash; standard ASN.1 padding will be done, as well as PKCS1 padding
       of the underlying RSA operation. */
    kSecPaddingPKCS1MD5  = 0x8001,

    /* For SecKeyRawSign/SecKeyRawVerify only, data to be signed is a SHA1
       hash; standard ASN.1 padding will be done, as well as PKCS1 padding
       of the underlying RSA operation. */
    kSecPaddingPKCS1SHA1 = 0x8002,
};

/*!
    @typedef SecKeySizes
    @abstract Supported key lengths.
*/
typedef CF_ENUM(uint32_t, SecKeySizes)
{
    kSecDefaultKeySize  = 0,

    // Symmetric Keysizes - default is currently kSecAES128 for AES.
    kSec3DES192         = 192,
    kSecAES128          = 128,
    kSecAES192          = 192,
    kSecAES256          = 256,

    // Supported ECC Keys for Suite-B from RFC 4492 section 5.1.1.
    // default is currently kSecp256r1
    kSecp192r1          = 192,
    kSecp256r1          = 256,
    kSecp384r1          = 384,
    kSecp521r1          = 521,  // Yes, 521

    // Boundaries for RSA KeySizes - default is currently 2048
    // RSA keysizes must be multiples of 8
    kSecRSAMin          = 1024,
    kSecRSAMax          = 4096
};

/*!
	@enum Key Parameter Constants
	@discussion Predefined key constants used to get or set values in a dictionary.
	These are used to provide explicit parameters to key generation functions
	when non-default values are desired. See the description of the
	SecKeyGeneratePair API for usage information.
	@constant kSecPrivateKeyAttrs The value for this key is a CFDictionaryRef
	 containing attributes specific for the private key to be generated.
	@constant kSecPublicKeyAttrs The value for this key is a CFDictionaryRef
	 containing attributes specific for the public key to be generated.
*/
extern const CFStringRef kSecPrivateKeyAttrs
    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_2_0);
extern const CFStringRef kSecPublicKeyAttrs
    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_2_0);


/*!
	@function SecKeyGetTypeID
	@abstract Returns the type identifier of SecKey instances.
	@result The CFTypeID of SecKey instances.
*/
CFTypeID SecKeyGetTypeID(void)
	__OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

/*!
	@function SecKeyCreatePair
	@abstract Creates an asymmetric key pair and stores it in a specified keychain.
	@param keychainRef A reference to the keychain in which to store the private and public key items. Specify NULL for the default keychain.
	@param algorithm An algorithm for the key pair. This parameter is ignored if a valid (non-zero) contextHandle is supplied.
	@param keySizeInBits A key size for the key pair. This parameter is ignored if a valid (non-zero) contextHandle is supplied.
	@param contextHandle (optional) A CSSM_CC_HANDLE, or 0. If this argument is supplied, the algorithm and keySizeInBits parameters are ignored. If extra parameters are needed to generate a key (some algorithms require this), you should create a context using CSSM_CSP_CreateKeyGenContext, using the CSPHandle obtained by calling SecKeychainGetCSPHandle. Then use CSSM_UpdateContextAttributes to add parameters, and dispose of the context using CSSM_DeleteContext after calling this function.
	@param publicKeyUsage A bit mask indicating all permitted uses for the new public key. CSSM_KEYUSE bit mask values are defined in cssmtype.h.
	@param publicKeyAttr A bit mask defining attribute values for the new public key. The bit mask values are equivalent to a CSSM_KEYATTR_FLAGS and are defined in cssmtype.h.
	@param privateKeyUsage A bit mask indicating all permitted uses for the new private key. CSSM_KEYUSE bit mask values are defined in cssmtype.h.
	@param privateKeyAttr A bit mask defining attribute values for the new private key. The bit mask values are equivalent to a CSSM_KEYATTR_FLAGS and are defined in cssmtype.h.
	@param initialAccess (optional) A SecAccess object that determines the initial access rights to the private key. The public key is given "any/any" access rights by default.
	@param publicKey (optional) On return, the keychain item reference of the generated public key. Use the SecKeyGetCSSMKey function to obtain the CSSM_KEY. The caller must call CFRelease on this value if it is returned. Pass NULL if a reference to this key is not required.
	@param privateKey (optional) On return, the keychain item reference of the generated private key. Use the SecKeyGetCSSMKey function to obtain the CSSM_KEY. The caller must call CFRelease on this value if it is returned. Pass NULL if a reference to this key is not required.
	@result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated for 10.7. Please use the SecKeyGeneratePair API instead.
*/
OSStatus SecKeyCreatePair(
        SecKeychainRef _Nullable keychainRef,
        CSSM_ALGORITHMS algorithm,
        uint32 keySizeInBits,
        CSSM_CC_HANDLE contextHandle,
        CSSM_KEYUSE publicKeyUsage,
        uint32 publicKeyAttr,
        CSSM_KEYUSE privateKeyUsage,
        uint32 privateKeyAttr,
        SecAccessRef _Nullable initialAccess,
        SecKeyRef* _Nullable CF_RETURNS_RETAINED publicKey,
        SecKeyRef* _Nullable CF_RETURNS_RETAINED privateKey)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
	@function SecKeyGenerate
	@abstract Creates a symmetric key and optionally stores it in a specified keychain.
	@param keychainRef (optional) A reference to the keychain in which to store the generated key. Specify NULL to generate a transient key.
	@param algorithm An algorithm for the symmetric key. This parameter is ignored if a valid (non-zero) contextHandle is supplied.
	@param keySizeInBits A key size for the key pair. This parameter is ignored if a valid (non-zero) contextHandle is supplied.
	@param contextHandle (optional) A CSSM_CC_HANDLE, or 0. If this argument is supplied, the algorithm and keySizeInBits parameters are ignored. If extra parameters are needed to generate a key (some algorithms require this), you should create a context using CSSM_CSP_CreateKeyGenContext, using the CSPHandle obtained by calling SecKeychainGetCSPHandle. Then use CSSM_UpdateContextAttributes to add parameters, and dispose of the context using CSSM_DeleteContext after calling this function.
	@param keyUsage A bit mask indicating all permitted uses for the new key. CSSM_KEYUSE bit mask values are defined in cssmtype.h.
	@param keyAttr A bit mask defining attribute values for the new key. The bit mask values are equivalent to a CSSM_KEYATTR_FLAGS and are defined in cssmtype.h.
	@param initialAccess (optional) A SecAccess object that determines the initial access rights for the key. This parameter is ignored if the keychainRef is NULL.
	@param keyRef On return, a reference to the generated key. Use the SecKeyGetCSSMKey function to obtain the CSSM_KEY. The caller must call CFRelease on this value if it is returned.
	@result A result code.  See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated for 10.7.  Please use the SecKeyGenerateSymmetric API instead.
*/
OSStatus SecKeyGenerate(
        SecKeychainRef _Nullable keychainRef,
        CSSM_ALGORITHMS algorithm,
        uint32 keySizeInBits,
        CSSM_CC_HANDLE contextHandle,
        CSSM_KEYUSE keyUsage,
        uint32 keyAttr,
        SecAccessRef _Nullable initialAccess,
        SecKeyRef* _Nullable CF_RETURNS_RETAINED keyRef)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecKeyGetCSSMKey
    @abstract Returns a pointer to the CSSM_KEY for the given key item reference.
    @param key A keychain key item reference. The key item must be of class type kSecPublicKeyItemClass, kSecPrivateKeyItemClass, or kSecSymmetricKeyItemClass.
    @param cssmKey On return, a pointer to a CSSM_KEY structure for the given key. This pointer remains valid until the key reference is released. The caller should not attempt to modify or free this data.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion  The CSSM_KEY is valid until the key item reference is released. This API is deprecated in 10.7. Its use should no longer be needed.
*/
OSStatus SecKeyGetCSSMKey(SecKeyRef key, const CSSM_KEY * _Nullable * __nonnull cssmKey)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;;

/*!
    @function SecKeyGetCSPHandle
    @abstract Returns the CSSM_CSP_HANDLE for the given key reference. The handle is valid until the key reference is released.
    @param keyRef A key reference.
    @param cspHandle On return, the CSSM_CSP_HANDLE for the given keychain.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated in 10.7. Its use should no longer be needed.
*/
OSStatus SecKeyGetCSPHandle(SecKeyRef keyRef, CSSM_CSP_HANDLE *cspHandle)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecKeyGetCredentials
    @abstract For a given key, return a pointer to a CSSM_ACCESS_CREDENTIALS structure which will allow the key to be used.
    @param keyRef The key for which a credential is requested.
    @param operation The type of operation to be performed with this key. See "Authorization tag type" for defined operations (cssmtype.h).
    @param credentialType The type of credential requested.
    @param outCredentials On return, a pointer to a CSSM_ACCESS_CREDENTIALS structure. This pointer remains valid until the key reference is released. The caller should not attempt to modify or free this data.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeyGetCredentials(
        SecKeyRef keyRef,
        CSSM_ACL_AUTHORIZATION_TAG operation,
        SecCredentialType credentialType,
        const CSSM_ACCESS_CREDENTIALS * _Nullable * __nonnull outCredentials)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
    @function SecKeyGetBlockSize
    @abstract Decrypt a block of ciphertext.
    @param key The key for which the block length is requested.
    @result The block length of the key in bytes.
    @discussion If for example key is an RSA key the value returned by
    this function is the size of the modulus.
 */
size_t SecKeyGetBlockSize(SecKeyRef key)
	__OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_2_0);

/*!
 @function	SecKeyGenerateSymmetric
 @abstract	Generates a random symmetric key with the specified length
 and algorithm type.

 @param parameters A dictionary containing one or more key-value pairs.
 See the discussion sections below for a complete overview of options.
 @param error An optional pointer to a CFErrorRef. This value is set
 if an error occurred. If not NULL, the caller is responsible for
 releasing the CFErrorRef.
 @result On return, a SecKeyRef reference to the symmetric key, or
 NULL if the key could not be created.

 @discussion In order to generate a symmetric key, the parameters dictionary
 must at least contain the following keys:

 * kSecAttrKeyType with a value of kSecAttrKeyTypeAES or any other
 kSecAttrKeyType defined in SecItem.h
 * kSecAttrKeySizeInBits with a value being a CFNumberRef containing
 the requested key size in bits.  Example sizes for AES keys are:
 128, 192, 256, 512.

 To store the generated symmetric key in a keychain, set these keys:
 * kSecUseKeychain (value is a SecKeychainRef)
 * kSecAttrLabel (a user-visible label whose value is a CFStringRef,
 e.g. "My App's Encryption Key")
 * kSecAttrApplicationLabel (a label defined by your application, whose
 value is a CFDataRef and which can be used to find this key in a
 subsequent call to SecItemCopyMatching, e.g. "ID-1234567890-9876-0151")

 To specify the generated key's access control settings, set this key:
 * kSecAttrAccess (value is a SecAccessRef)

 The keys below may be optionally set in the parameters dictionary
 (with a CFBooleanRef value) to override the default usage values:

 * kSecAttrCanEncrypt (defaults to true if not explicitly specified)
 * kSecAttrCanDecrypt (defaults to true if not explicitly specified)
 * kSecAttrCanWrap (defaults to true if not explicitly specified)
 * kSecAttrCanUnwrap (defaults to true if not explicitly specified)

*/
_Nullable
SecKeyRef SecKeyGenerateSymmetric(CFDictionaryRef parameters, CFErrorRef *error)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);


/*!
 @function SecKeyCreateFromData
 @abstract Creates a symmetric key with the given data and sets the
 algorithm type specified.

 @param parameters A dictionary containing one or more key-value pairs.
 See the discussion sections below for a complete overview of options.
 @result On return, a SecKeyRef reference to the symmetric key.

 @discussion In order to generate a symmetric key the parameters dictionary must
 at least contain the following keys:

 * kSecAttrKeyType with a value of kSecAttrKeyTypeAES or any other
 kSecAttrKeyType defined in SecItem.h

 The keys below may be optionally set in the parameters dictionary
 (with a CFBooleanRef value) to override the default usage values:

 * kSecAttrCanEncrypt (defaults to true if not explicitly specified)
 * kSecAttrCanDecrypt (defaults to true if not explicitly specified)
 * kSecAttrCanWrap (defaults to true if not explicitly specified)
 * kSecAttrCanUnwrap (defaults to true if not explicitly specified)

*/
_Nullable
SecKeyRef SecKeyCreateFromData(CFDictionaryRef parameters,
	CFDataRef keyData, CFErrorRef *error)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);


/*!
 @function SecKeyGeneratePair
 @abstract Generate a private/public keypair.
 @param parameters A dictionary containing one or more key-value pairs.
 @result A result code. See "Security Error Codes" (SecBase.h). On success,
 the result code will be errSecSuccess, and the output parameters will
 contain the public SecKeyRef and private SecKeyRef. It is the caller's
 responsibility to CFRelease these key references when finished with them.

 @discussion In order to generate a keypair the parameters dictionary must
 at least contain the following keys:

 * kSecAttrKeyType with a value of kSecAttrKeyTypeRSA or any other
 kSecAttrKeyType defined in SecItem.h
 * kSecAttrKeySizeInBits with a value being a CFNumberRef containing
 the requested key size in bits.  Example sizes for RSA keys are:
 512, 768, 1024, 2048.

 The values below may be set either in the top-level dictionary or in a
 dictionary that is the value of the kSecPrivateKeyAttrs or
 kSecPublicKeyAttrs key in the top-level dictionary.  Setting these
 attributes explicitly will override the defaults below.  See SecItem.h
 for detailed information on these attributes including the types of
 the values.

 * kSecAttrLabel default NULL
 * kSecUseKeychain default NULL, which specifies the default keychain
 * kSecAttrApplicationTag default NULL
 * kSecAttrEffectiveKeySize default NULL same as kSecAttrKeySizeInBits
 * kSecAttrCanEncrypt default false for private keys, true for public keys
 * kSecAttrCanDecrypt default true for private keys, false for public keys
 * kSecAttrCanDerive default true
 * kSecAttrCanSign default true for private keys, false for public keys
 * kSecAttrCanVerify default false for private keys, true for public keys
 * kSecAttrCanWrap default false for private keys, true for public keys
 * kSecAttrCanUnwrap default true for private keys, false for public keys

*/
OSStatus SecKeyGeneratePair(CFDictionaryRef parameters,
	SecKeyRef * _Nullable CF_RETURNS_RETAINED publicKey, SecKeyRef * _Nullable CF_RETURNS_RETAINED privateKey)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_2_0);

/*!
 @typedef SecKeyGeneratePairBlock
 @abstract Delivers the result from an asynchronous key pair generation.
 @param publicKey - the public key generated.   You must retain publicKey if you wish to use it after your block returns.
 @param privateKey - the private key generated.  You must retain publicKey if you wish to use it after your block returns.
 @param error - Any errors returned.   You must retain error if you wish to use it after your block returns.
 */

#ifdef __BLOCKS__
typedef void (^SecKeyGeneratePairBlock)(SecKeyRef publicKey, SecKeyRef privateKey,  CFErrorRef error);


/*!
 @function SecKeyGeneratePairAsync
 @abstract Generate a private/public keypair returning the values in a callback.
 @param parameters A dictionary containing one or more key-value pairs.
 @param deliveryQueue A dispatch queue to be used to deliver the results.
 @param result A callback function to result when the operation has completed.

 @discussion In order to generate a keypair the parameters dictionary must
 at least contain the following keys:

 * kSecAttrKeyType with a value being kSecAttrKeyTypeRSA or any other
 kSecAttrKeyType defined in SecItem.h
 * kSecAttrKeySizeInBits with a value being a CFNumberRef or CFStringRef
 containing the requested key size in bits.  Example sizes for RSA
 keys are: 512, 768, 1024, 2048.

 Setting the following attributes explicitly will override the defaults below.
 See SecItem.h for detailed information on these attributes including the types
 of the values.

 * kSecAttrLabel default NULL
 * kSecAttrIsPermanent if this key is present and has a Boolean
 value of true, the key or key pair will be added to the default
 keychain.
 * kSecAttrApplicationTag default NULL
 * kSecAttrEffectiveKeySize default NULL same as kSecAttrKeySizeInBits
 * kSecAttrCanEncrypt default false for private keys, true for public keys
 * kSecAttrCanDecrypt default true for private keys, false for public keys
 * kSecAttrCanDerive default true
 * kSecAttrCanSign default true for private keys, false for public keys
 * kSecAttrCanVerify default false for private keys, true for public keys
 * kSecAttrCanWrap default false for private keys, true for public keys
 * kSecAttrCanUnwrap default true for private keys, false for public keys

*/
void SecKeyGeneratePairAsync(CFDictionaryRef parameters,
	dispatch_queue_t deliveryQueue, SecKeyGeneratePairBlock result)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

#endif /* __BLOCKS__ */

// Derive, Wrap, and Unwrap

/*!
 @function SecKeyDeriveFromPassword
 @abstract Derives a symmetric key from a password.

 @param password The password from which the keyis to be derived.
 @param parameters A dictionary containing one or more key-value pairs.
 @param error If the call fails this will contain the error code.

 @discussion In order to derive a key the parameters dictionary must contain at least contain the following keys:
 * kSecAttrSalt	- a CFData for the salt value for mixing in the pseudo-random rounds.
 * kSecAttrPRF - the algorithm to use for the pseudo-random-function.
   If 0, this defaults to kSecAttrPRFHmacAlgSHA1. Possible values are:

 * kSecAttrPRFHmacAlgSHA1
 * kSecAttrPRFHmacAlgSHA224
 * kSecAttrPRFHmacAlgSHA256
 * kSecAttrPRFHmacAlgSHA384
 * kSecAttrPRFHmacAlgSHA512

 * kSecAttrRounds - the number of rounds to call the pseudo random function.
   If 0, a count will be computed to average 1/10 of a second.
 * kSecAttrKeySizeInBits with a value being a CFNumberRef
   containing the requested key size in bits.  Example sizes for RSA keys are:
   512, 768, 1024, 2048.

 @result On success a SecKeyRef is returned.  On failure this result is NULL and the
 error parameter contains the reason.

*/
_Nullable CF_RETURNS_RETAINED
SecKeyRef SecKeyDeriveFromPassword(CFStringRef password,
	CFDictionaryRef parameters, CFErrorRef *error)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
 @function SecKeyWrapSymmetric
 @abstract Wraps a symmetric key with a symmetric key.

 @param keyToWrap The key which is to be wrapped.
 @param wrappingKey The key wrapping key.
 @param parameters The parameter list to use for wrapping the key.
 @param error If the call fails this will contain the error code.

 @result On success a CFDataRef is returned.  On failure this result is NULL and the
 error parameter contains the reason.

 @discussion In order to wrap a key the parameters dictionary may contain the following key:
 * kSecSalt	- a CFData for the salt value for the encrypt.

*/
_Nullable
CFDataRef SecKeyWrapSymmetric(SecKeyRef keyToWrap,
	SecKeyRef wrappingKey, CFDictionaryRef parameters, CFErrorRef *error)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
 @function SecKeyUnwrapSymmetric
 @abstract Unwrap a wrapped symmetric key.

 @param keyToUnwrap The wrapped key to unwrap.
 @param unwrappingKey The key unwrapping key.
 @param parameters The parameter list to use for unwrapping the key.
 @param error If the call fails this will contain the error code.

 @result On success a SecKeyRef is returned.  On failure this result is NULL and the
 error parameter contains the reason.

 @discussion In order to unwrap a key the parameters dictionary may contain the following key:
 * kSecSalt	- a CFData for the salt value for the decrypt.

*/
_Nullable
SecKeyRef SecKeyUnwrapSymmetric(CFDataRef _Nullable * __nonnull keyToUnwrap,
	SecKeyRef unwrappingKey, CFDictionaryRef parameters, CFErrorRef *error)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
 @function SecKeyCreateRandomKey
 @abstract Generates a new public/private key pair.
 @param parameters A dictionary containing one or more key-value pairs.
	See the discussion sections below for a complete overview of options.
 @param error On error, will be populated with an error object describing the failure.
 See "Security Error Codes" (SecBase.h).
 @return Newly generated private key.  To get associated public key, use SecKeyCopyPublicKey().
 @discussion In order to generate a keypair the parameters dictionary must
	at least contain the following keys:

 * kSecAttrKeyType with a value being kSecAttrKeyTypeRSA or any other
 kSecAttrKeyType defined in SecItem.h
 * kSecAttrKeySizeInBits with a value being a CFNumberRef or CFStringRef
 containing the requested key size in bits.  Example sizes for RSA
 keys are: 512, 768, 1024, 2048.

 The values below may be set either in the top-level dictionary or in a
 dictionary that is the value of the kSecPrivateKeyAttrs or
 kSecPublicKeyAttrs key in the top-level dictionary.  Setting these
 attributes explicitly will override the defaults below.  See SecItem.h
 for detailed information on these attributes including the types of
 the values.

 * kSecAttrLabel default NULL
 * kSecAttrIsPermanent if this key is present and has a Boolean value of true,
   the key or key pair will be added to the default keychain.
 * kSecAttrTokenID if this key should be generated on specified token.  This
   attribute can contain CFStringRef and can be present only in the top-level
   parameters dictionary.
 * kSecAttrApplicationTag default NULL
 * kSecAttrEffectiveKeySize default NULL same as kSecAttrKeySizeInBits
 * kSecAttrCanEncrypt default false for private keys, true for public keys
 * kSecAttrCanDecrypt default true for private keys, false for public keys
 * kSecAttrCanDerive default true
 * kSecAttrCanSign default true for private keys, false for public keys
 * kSecAttrCanVerify default false for private keys, true for public keys
 * kSecAttrCanWrap default false for private keys, true for public keys
 * kSecAttrCanUnwrap default true for private keys, false for public keys
 */
SecKeyRef _Nullable SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCreateWithData
	@abstract Create a SecKey from a well-defined external representation.
	@param keyData CFData representing the key. The format of the data depends on the type of key being created.
	@param attributes Dictionary containing attributes describing the key to be imported. The keys in this dictionary
 	are kSecAttr* constants from SecItem.h.  Mandatory attributes are:
	 * kSecAttrKeyType
	 * kSecAttrKeyClass
	 * kSecAttrKeySizeInBits
	@param error On error, will be populated with an error object describing the failure.
 	See "Security Error Codes" (SecBase.h).
	@result A SecKey object representing the key, or NULL on failure.
	@discussion This function does not add keys to any keychain, but the SecKey object it returns can be added
 	to keychain using the SecItemAdd function.
	The requested data format depend on the type of key (kSecAttrKeyType) being created:
	 * kSecAttrKeyTypeRSA               PKCS#1 format
	 * kSecAttrKeyTypeECSECPrimeRandom  SEC1 format (www.secg.org)
 */
SecKeyRef _Nullable SecKeyCreateWithData(CFDataRef keyData, CFDictionaryRef attributes, CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCopyExternalRepresentation
	@abstract Create an external representation for the given key suitable for the key's type.
	@param key The key to be exported.
	@param error On error, will be populated with an error object describing the failure.
 	See "Security Error Codes" (SecBase.h).
	@result A CFData representing the key in a format suitable for that key type.
	@discussion This function may fail if the key is not exportable (e.g., bound to a smart card or Secure Enclave).
	The format in which the key will be exported depends on the type of key:
	* kSecAttrKeyTypeRSA                 PKCS#1 format
	* kSecAttrKeyTypeECSECPrimeRandom    SEC1 format (www.secg.org)
 */
CFDataRef _Nullable SecKeyCopyExternalRepresentation(SecKeyRef key, CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCopyAttributes
	@abstract Retrieve keychain attributes of a key.
	@param key The key whose attributes are to be retrieved.
	@result Dictionary containing attributes of the key. The keys that populate this dictionary are defined
 	and discussed in SecItem.h.
	@discussion The attributes provided by this function are:
	* kSecAttrCanEncrypt
	* kSecAttrCanDecrypt
	* kSecAttrCanDerive
	* kSecAttrCanSign
	* kSecAttrCanVerify
	* kSecAttrKeyClass
	* kSecAttrKeyType
	* kSecAttrKeySizeInBits
	* kSecAttrTokenID
	* kSecAttrApplicationLabel
	Other values returned in that dictionary are RFU.
 */
CFDictionaryRef _Nullable SecKeyCopyAttributes(SecKeyRef key)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCopyPublicKey
	@abstract Retrieve the public key from a key pair or private key.
	@param key The key from which to retrieve a public key.
	@result The public key or NULL if public key is not available for specified key.
	@discussion Fails if key does not contain a public key or no public key can be computed from it.
 */
SecKeyRef _Nullable SecKeyCopyPublicKey(SecKeyRef key)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@enum SecKeyAlgorithm
	@abstract Available algorithms for performing cryptographic operations with SecKey object.  String representation
	of constant can be used for logging or debugging purposes, because they contain human readable names of the algorithm.

	@constant kSecKeyAlgorithmRSASignatureRaw
	Raw RSA sign/verify operation, size of input data must be the same as value returned by SecKeyGetBlockSize().

 	@constant kSecKeyAlgorithmRSASignatureDigestPKCS1v15Raw
 	RSA sign/verify operation, assumes that input data is digest and OID and digest algorithm as specified in PKCS# v1.5.
	This algorithm is typically not used directly, instead use algorithm with specified digest, like
 	kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256.

	@constant kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1
	RSA signature with PKCS#1 padding, input data must be SHA-1 generated digest.

	@constant kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA224
	RSA signature with PKCS#1 padding, input data must be SHA-224 generated digest.

	@constant kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256
	RSA signature with PKCS#1 padding, input data must be SHA-256 generated digest.

	@constant kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384
	RSA signature with PKCS#1 padding, input data must be SHA-384 generated digest.

	@constant kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512
	RSA signature with PKCS#1 padding, input data must be SHA-512 generated digest.

	@constant kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1
	RSA signature with PKCS#1 padding, SHA-1 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224
	RSA signature with PKCS#1 padding, SHA-224 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256
	RSA signature with PKCS#1 padding, SHA-256 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384
	RSA signature with PKCS#1 padding, SHA-384 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512
	RSA signature with PKCS#1 padding, SHA-512 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmECDSASignatureRFC4754
	ECDSA algorithm, signature is concatenated r and s, big endian, data is message digest.

	@constant kSecKeyAlgorithmECDSASignatureDigestX962
	ECDSA algorithm, signature is in DER x9.62 encoding, input data is message digest.

	@constant kSecKeyAlgorithmECDSASignatureDigestX962SHA1
	ECDSA algorithm, signature is in DER x9.62 encoding, input data is message digest created by SHA1 algorithm.

	@constant kSecKeyAlgorithmECDSASignatureDigestX962SHA1
	ECDSA algorithm, signature is in DER x9.62 encoding, input data is message digest created by SHA224 algorithm.

	@constant kSecKeyAlgorithmECDSASignatureDigestX962SHA1
	ECDSA algorithm, signature is in DER x9.62 encoding, input data is message digest created by SHA256 algorithm.

	@constant kSecKeyAlgorithmECDSASignatureDigestX962SHA1
	ECDSA algorithm, signature is in DER x9.62 encoding, input data is message digest created by SHA384 algorithm.

	@constant kSecKeyAlgorithmECDSASignatureDigestX962SHA1
	ECDSA algorithm, signature is in DER x9.62 encoding, input data is message digest created by SHA512 algorithm.

	@constant kSecKeyAlgorithmECDSASignatureMessageX962SHA1
	ECDSA algorithm, signature is in DER x9.62 encoding, SHA-1 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmECDSASignatureMessageX962SHA224
	ECDSA algorithm, signature is in DER x9.62 encoding, SHA-224 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmECDSASignatureMessageX962SHA256
	ECDSA algorithm, signature is in DER x9.62 encoding, SHA-256 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmECDSASignatureMessageX962SHA384
	ECDSA algorithm, signature is in DER x9.62 encoding, SHA-384 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmECDSASignatureMessageX962SHA512
	ECDSA algorithm, signature is in DER x9.62 encoding, SHA-512 digest is generated from input data of any size.

	@constant kSecKeyAlgorithmRSAEncryptionRaw
	Raw RSA encryption or decryption, size of data must match RSA key modulus size.  Note that direct
	use of this algorithm without padding is cryptographically very weak, it is important to always introduce
	some kind of padding.  Input data size must be less or equal to the key block size and returned block has always
	the same size as block size, as returned by SecKeyGetBlockSize().

	@constant kSecKeyAlgorithmRSAEncryptionPKCS1
	RSA encryption or decryption, data is padded using PKCS#1 padding scheme.  This algorithm should be used only for
	backward compatibility with existing protocols and data. New implementations should choose cryptographically
	stronger algorithm instead (see kSecKeyAlgorithmRSAEncryptionOAEP).  Input data must be at most
 	"key block size - 11" bytes long and returned block has always the same size as block size, as returned
	by SecKeyGetBlockSize().

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA1
	RSA encryption or decryption, data is padded using OAEP padding scheme internally using SHA1. Input data must be at most
	"key block size - 42" bytes long and returned block has always the same size as block size, as returned
	by SecKeyGetBlockSize().  Use kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM to be able to encrypt and decrypt arbitrary long data.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA224
	RSA encryption or decryption, data is padded using OAEP padding scheme internally using SHA224. Input data must be at most
	"key block size - 58" bytes long and returned block has always the same size as block size, as returned
	by SecKeyGetBlockSize().  Use kSecKeyAlgorithmRSAEncryptionOAEPSHA224AESGCM to be able to encrypt and decrypt arbitrary long data.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA256
	RSA encryption or decryption, data is padded using OAEP padding scheme internally using SHA256. Input data must be at most
	"key block size - 66" bytes long and returned block has always the same size as block size, as returned
	by SecKeyGetBlockSize().  Use kSecKeyAlgorithmRSAEncryptionOAEPSHA256AESGCM to be able to encrypt and decrypt arbitrary long data.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA384
	RSA encryption or decryption, data is padded using OAEP padding scheme internally using SHA384. Input data must be at most
	"key block size - 98" bytes long and returned block has always the same size as block size, as returned
	by SecKeyGetBlockSize().  Use kSecKeyAlgorithmRSAEncryptionOAEPSHA384AESGCM to be able to encrypt and decrypt arbitrary long data.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA512
	RSA encryption or decryption, data is padded using OAEP padding scheme internally using SHA512. Input data must be at most
	"key block size - 130" bytes long and returned block has always the same size as block size, as returned
	by SecKeyGetBlockSize().  Use kSecKeyAlgorithmRSAEncryptionOAEPSHA512AESGCM to be able to encrypt and decrypt arbitrary long data.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM
 	Randomly generated AES session key is encrypted by RSA with OAEP padding.  User data are encrypted using session key in GCM
 	mode with all-zero 16 bytes long IV (initialization vector).  Finally 16 byte AES-GCM tag is appended to ciphertext.
	256bit AES key is used if RSA key is 4096bit or bigger, otherwise 128bit AES key is used.  Raw public key data is used
 	as authentication data for AES-GCM encryption.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA224AESGCM
 	Randomly generated AES session key is encrypted by RSA with OAEP padding.  User data are encrypted using session key in GCM
 	mode with all-zero 16 bytes long IV (initialization vector).  Finally 16 byte AES-GCM tag is appended to ciphertext.
	256bit AES key is used if RSA key is 4096bit or bigger, otherwise 128bit AES key is used.  Raw public key data is used
 	as authentication data for AES-GCM encryption.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA256AESGCM
 	Randomly generated AES session key is encrypted by RSA with OAEP padding.  User data are encrypted using session key in GCM
 	mode with all-zero 16 bytes long IV (initialization vector).  Finally 16 byte AES-GCM tag is appended to ciphertext.
	256bit AES key is used if RSA key is 4096bit or bigger, otherwise 128bit AES key is used.  Raw public key data is used
 	as authentication data for AES-GCM encryption.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA384AESGCM
 	Randomly generated AES session key is encrypted by RSA with OAEP padding.  User data are encrypted using session key in GCM
 	mode with all-zero 16 bytes long IV (initialization vector).  Finally 16 byte AES-GCM tag is appended to ciphertext.
	256bit AES key is used if RSA key is 4096bit or bigger, otherwise 128bit AES key is used.  Raw public key data is used
 	as authentication data for AES-GCM encryption.

	@constant kSecKeyAlgorithmRSAEncryptionOAEPSHA512AESGCM
 	Randomly generated AES session key is encrypted by RSA with OAEP padding.  User data are encrypted using session key in GCM
 	mode with all-zero 16 bytes long IV (initialization vector).  Finally 16 byte AES-GCM tag is appended to ciphertext.
	256bit AES key is used if RSA key is 4096bit or bigger, otherwise 128bit AES key is used.  Raw public key data is used
 	as authentication data for AES-GCM encryption.

 	@constant kSecKeyAlgorithmECIESEncryptionStandardX963SHA1AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionStandardX963SHA224AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionStandardX963SHA256AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionStandardX963SHA384AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionStandardX963SHA512AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionCofactorX963SHA1AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionCofactorX963SHA224AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionCofactorX963SHA384AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

 	@constant kSecKeyAlgorithmECIESEncryptionCofactorX963SHA512AESGCM
	ECIES encryption or decryption.  This algorithm does not limit the size of the message to be encrypted or decrypted.
	Encryption is done using AES-GCM with key negotiated by kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1.  AES Key size
	is 128bit for EC keys <=256bit and 256bit for bigger EC keys.  Ephemeral public key data is used as sharedInfo for KDF,
	and static public key data is used as authenticationData for AES-GCM processing.  AES-GCM uses 16 bytes long TAG and
 	all-zero 16 byte long IV (initialization vector).

	@constant kSecKeyAlgorithmECDHKeyExchangeCofactor
	Compute shared secret using ECDH cofactor algorithm, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys.
	This algorithm does not accept any parameters, length of output raw shared secret is given by the length of the key.

	@constant kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1
	Compute shared secret using ECDH cofactor algorithm, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA1 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA224
	Compute shared secret using ECDH cofactor algorithm, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA224 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA256
	Compute shared secret using ECDH cofactor algorithm, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA256 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA384
	Compute shared secret using ECDH cofactor algorithm, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA384 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA512
	Compute shared secret using ECDH cofactor algorithm, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA512 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeStandard
	Compute shared secret using ECDH algorithm without cofactor, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys.
	This algorithm does not accept any parameters, length of output raw shared secret is given by the length of the key.

	@constant kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1
	Compute shared secret using ECDH algorithm without cofactor, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA1 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA224
	Compute shared secret using ECDH algorithm without cofactor, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA224 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA256
	Compute shared secret using ECDH algorithm without cofactor, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA256 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA384
	Compute shared secret using ECDH algorithm without cofactor, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA384 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.

	@constant kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA512
	Compute shared secret using ECDH algorithm without cofactor, suitable only for kSecAttrKeyTypeECSECPrimeRandom keys
	and apply ANSI X9.63 KDF with SHA512 as hashing function.  Requires kSecKeyKeyExchangeParameterRequestedSize and allows
	kSecKeyKeyExchangeParameterSharedInfo parameters to be used.
  */

typedef CFStringRef SecKeyAlgorithm CF_STRING_ENUM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureRaw
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureDigestPKCS1v15Raw
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA224
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureRFC4754
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestX962
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestX962SHA1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestX962SHA224
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestX962SHA256
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestX962SHA384
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestX962SHA512
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageX962SHA1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageX962SHA224
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageX962SHA256
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageX962SHA384
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageX962SHA512
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionRaw
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionPKCS1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA224
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA256
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA384
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA512
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA224AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA256AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA384AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA512AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionStandardX963SHA1AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionStandardX963SHA224AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionStandardX963SHA256AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionStandardX963SHA384AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionStandardX963SHA512AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionCofactorX963SHA1AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionCofactorX963SHA224AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionCofactorX963SHA384AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECIESEncryptionCofactorX963SHA512AESGCM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeStandard
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA224
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA256
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA384
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA512
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeCofactor
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA224
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA256
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA384
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyAlgorithm kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA512
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCreateSignature
	@abstract Given a private key and data to sign, generate a digital signature.
	@param key Private key with which to sign.
	@param algorithm One of SecKeyAlgorithm constants suitable to generate signature with this key.
	@param dataToSign The data to be signed, typically the digest of the actual data.
	@param error On error, will be populated with an error object describing the failure.
 	See "Security Error Codes" (SecBase.h).
	@result The signature over dataToSign represented as a CFData, or NULL on failure.
	@discussion Computes digital signature using specified key over input data.  The operation algorithm
	further defines the exact format of input data, operation to be performed and output signature.
 */
CFDataRef _Nullable SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyVerifySignature
	@abstract Given a public key, data which has been signed, and a signature, verify the signature.
	@param key Public key with which to verify the signature.
	@param algorithm One of SecKeyAlgorithm constants suitable to verify signature with this key.
	@param signedData The data over which sig is being verified, typically the digest of the actual data.
	@param signature The signature to verify.
	@param error On error, will be populated with an error object describing the failure.
 	See "Security Error Codes" (SecBase.h).
	@result True if the signature was valid, False otherwise.
	@discussion Verifies digital signature operation using specified key and signed data.  The operation algorithm
	further defines the exact format of input data, signature and operation to be performed.
 */
Boolean SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData, CFDataRef signature, CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCreateEncryptedData
	@abstract Encrypt a block of plaintext.
	@param key Public key with which to encrypt the data.
	@param algorithm One of SecKeyAlgorithm constants suitable to perform encryption with this key.
	@param plaintext The data to encrypt. The length and format of the data must conform to chosen algorithm,
	typically be less or equal to the value returned by SecKeyGetBlockSize().
	@param error On error, will be populated with an error object describing the failure.
 	See "Security Error Codes" (SecBase.h).
	@result The ciphertext represented as a CFData, or NULL on failure.
	@discussion Encrypts plaintext data using specified key.  The exact type of the operation including the format
	of input and output data is specified by encryption algorithm.
 */
CFDataRef _Nullable SecKeyCreateEncryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext,
                                               CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCreateDecryptedData
	@abstract Decrypt a block of ciphertext.
	@param key Private key with which to decrypt the data.
	@param algorithm One of SecKeyAlgorithm constants suitable to perform decryption with this key.
	@param ciphertext The data to decrypt. The length and format of the data must conform to chosen algorithm,
	typically be less or equal to the value returned by SecKeyGetBlockSize().
	@param error On error, will be populated with an error object describing the failure.
 	See "Security Error Codes" (SecBase.h).
	@result The plaintext represented as a CFData, or NULL on failure.
	@discussion Decrypts ciphertext data using specified key.  The exact type of the operation including the format
	of input and output data is specified by decryption algorithm.
 */
CFDataRef _Nullable SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext,
                                               CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@enum SecKeyKeyExchangeParameter SecKey Key Exchange parameters
	@constant kSecKeyKeyExchangeParameterRequestedSize Contains CFNumberRef with requested result size in bytes.
	@constant kSecKeyKeyExchangeParameterSharedInfo Contains CFDataRef with additional shared info
	for KDF (key derivation function).
 */
typedef CFStringRef SecKeyKeyExchangeParameter CF_STRING_ENUM
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyKeyExchangeParameter kSecKeyKeyExchangeParameterRequestedSize
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
extern const SecKeyKeyExchangeParameter kSecKeyKeyExchangeParameterSharedInfo
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyCopyKeyExchangeResult
	@abstract Perform Diffie-Hellman style of key exchange operation, optionally with additional key-derivation steps.
	@param algorithm One of SecKeyAlgorithm constants suitable to perform this operation.
	@param publicKey Remote party's public key.
	@param parameters Dictionary with parameters, see SecKeyKeyExchangeParameter constants.  Used algorithm
	determines the set of required and optional parameters to be used.
	@param error Pointer to an error object on failure.
	See "Security Error Codes" (SecBase.h).
	@result Result of key exchange operation as a CFDataRef, or NULL on failure.
 */
CFDataRef _Nullable SecKeyCopyKeyExchangeResult(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey, CFDictionaryRef parameters, CFErrorRef *error)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@enum SecKeyOperationType
 	@abstract Defines types of cryptographic operations available with SecKey instance.

	@constant kSecKeyOperationTypeSign
	Represents SecKeyCreateSignature()

	@constant kSecKeyOperationTypeVerify
	Represents SecKeyVerifySignature()

	@constant kSecKeyOperationTypeEncrypt
	Represents SecKeyCreateEncryptedData()

	@constant kSecKeyOperationTypeDecrypt
	Represents SecKeyCreateDecryptedData()

	@constant kSecKeyOperationTypeKeyExchange
	Represents SecKeyCopyKeyExchangeResult()
 */
typedef CF_ENUM(CFIndex, SecKeyOperationType) {
    kSecKeyOperationTypeSign        = 0,
    kSecKeyOperationTypeVerify      = 1,
    kSecKeyOperationTypeEncrypt     = 2,
    kSecKeyOperationTypeDecrypt     = 3,
    kSecKeyOperationTypeKeyExchange = 4,
} __OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

/*!
	@function SecKeyIsAlgorithmSupported
	@abstract Checks whether key supports specified algorithm for specified operation.
	@param key Key to query
	@param operation Operation type for which the key is queried
	@param algorithm Algorithm which is queried
	@return True if key supports specified algorithm for specified operation, False otherwise.
 */
Boolean SecKeyIsAlgorithmSupported(SecKeyRef key, SecKeyOperationType operation, SecKeyAlgorithm algorithm)
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECKEY_H_ */
