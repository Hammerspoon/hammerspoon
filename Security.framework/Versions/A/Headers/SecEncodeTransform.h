#ifndef __SECENCODETRANSFORM_H__
#define __SECENCODETRANSFORM_H__

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

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
    @abstract Specifies a base 64 encoding
 */
extern const CFStringRef kSecBase64Encoding;

/*!
    @abstract Specifies a base 32 encoding
 */
extern const CFStringRef kSecBase32Encoding;

/*!
    @abstract Specifies a compressed encoding.
 */
extern const CFStringRef kSecZLibEncoding;

/*!
 @constant kSecEncodeTypeAttribute
 Used with SecTransformGetAttribute to query the attribute type.
 Returns one of the strings defined in the previous section.
 */

extern const CFStringRef kSecEncodeTypeAttribute;


extern const CFStringRef kSecLineLength64;
extern const CFStringRef kSecLineLength76;
	
/*!
 @constant kSecEncodeLineLengthAttribute
 Used with SecTransformSetAttribute to set the length
 of encoded Base32 or Base64 lines.   Some systems will
 not decode or otherwise deal with excessively long lines,
 or may be defined to limit lines to specific lengths
 (for example RFC1421 - 64, and RFC2045 - 76).

 The LineLengthAttribute may be set to any positive
 value (via a CFNumberRef) to limit to a specific
 length (values smaller then X for Base32 or Y for Base64
 are assume to be X or Y), or to zero for no specific
 limit.   Either of the string constants kSecLineLength64
 (RFC1421), or kSecLineLength76 (RFC2045) may be used to
 set line lengths of 64 or 76 bytes.
 */
extern const CFStringRef kSecEncodeLineLengthAttribute;

extern const CFStringRef kSecCompressionRatio;

/*!
 @function SecEncodeTransformCreate
 @abstract			Creates an encode computation object.
 @param encodeType	The type of digest to compute.  You may pass NULL
 for this parameter, in which case an appropriate
 algorithm will be chosen for you.
 @param error		A pointer to a CFErrorRef.  This pointer will be set
 if an error occurred.  This value may be NULL if you
 do not want an error returned.
 @result				A pointer to a SecTransformRef object.  This object must
 be released with CFRelease when you are done with
 it.  This function will return NULL if an error
 occurred.
 @discussion			This function creates a transform which computes an
 encode.
 */

// See SecDecodeTransformCreate for decoding...
__nullable
SecTransformRef SecEncodeTransformCreate(CFTypeRef encodeType,
										 CFErrorRef* error
										 )
__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);
	
CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif
		

#endif
