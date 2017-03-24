#ifndef __TRANSFORM_SIGN_VERIFY__
#define __TRANSFORM_SIGN_VERIFY__


/*
 * Copyright (c) 2010-2011 Apple Inc. All Rights Reserved.
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

#include "SecTransform.h"
#include <Security/SecBase.h>


#ifdef __cplusplus
extern "C" {
#endif

    CF_ASSUME_NONNULL_BEGIN
    CF_IMPLICIT_BRIDGING_ENABLED

	extern const CFStringRef kSecKeyAttributeName, kSecSignatureAttributeName, kSecInputIsAttributeName;
	// WARNING: kSecInputIsRaw is frequently cryptographically unsafe (for example if you don't blind a DSA or ECDSA signature you give away the key very quickly), please only use it if you really know the math.
	extern const CFStringRef kSecInputIsPlainText, kSecInputIsDigest, kSecInputIsRaw;
	// Supported optional attributes: kSecDigestTypeAttribute (kSecDigestMD2, kSecDigestMD4, kSecDigestMD5, kSecDigestSHA1, kSecDigestSHA2), kSecDigestLengthAttribute
	
	/*!
	 @function SecSignTransformCreate
	 @abstract			Creates a sign computation object.
	 @param key		A SecKey with the private key used for signing.
	 @param error		A pointer to a CFErrorRef.  This pointer will be set
	 if an error occurred.  This value may be NULL if you
	 do not want an error returned.
	 @result				A pointer to a SecTransformRef object.  This object must
	 be released with CFRelease when you are done with
	 it.  This function will return NULL if an error
	 occurred.
	 @discussion			This function creates a transform which computes a
	 cryptographic signature.   The InputIS defaults to kSecInputIsPlainText,
	 and the DigestType and DigestLength default to something appropriate for
	 the type of key you have supplied.
	 */

	__nullable
	SecTransformRef SecSignTransformCreate(SecKeyRef key,
											 CFErrorRef* error
											 )
	__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);
	
	/*!
	 @function SecVerifyTransformCreate
	 @abstract			Creates a verify computation object.
	 @param key		A SecKey with the public key used for signing.
	 @param signature	A CFDataRef with the signature.   This value may be
	 NULL, and you may connect a transform to kSecTransformSignatureAttributeName
	 to supply it from another signature.
	 @param error		A pointer to a CFErrorRef.  This pointer will be set
	 if an error occurred.  This value may be NULL if you
	 do not want an error returned.
	 @result				A pointer to a SecTransformRef object.  This object must
	 be released with CFRelease when you are done with
	 it.  This function will return NULL if an error
	 occurred.
	 @discussion			This function creates a transform which verifies a
	 cryptographic signature.  The InputIS defaults to kSecInputIsPlainText,
	 and the DigestType and DigestLength default to something appropriate for
	 the type of key you have supplied.
	 */

    __nullable
	SecTransformRef SecVerifyTransformCreate(SecKeyRef key,
											 CFDataRef __nullable signature,
											 CFErrorRef* error
											 )
	__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

    CF_IMPLICIT_BRIDGING_DISABLED
    CF_ASSUME_NONNULL_END
	
#ifdef __cplusplus
};
#endif


#endif
