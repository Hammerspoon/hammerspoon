#ifndef __SECDECODETRANSFORM_H__
#define __SECDECODETRANSFORM_H__

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

#include "SecEncodeTransform.h"

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

	/*!
	 @constant kSecDecodeTypeAttribute
	 Used with SecTransformGetAttribute to query the attribute type.
	 Returns one of the strings defined in the previous section.
	 */
	
	extern const CFStringRef kSecDecodeTypeAttribute;
	
	/*!
	 @function SecDecodeTransformCreate
	 @abstract			Creates an decode computation object.
	 @param DecodeType	The type of digest to decode.  You may pass NULL
	 for this parameter, in which case an appropriate
	 algorithm will be chosen for you.
	 @param error		A pointer to a CFErrorRef.  This pointer will be set
	 if an error occurred.  This value may be NULL if you
	 do not want an error returned.
	 @result				A pointer to a SecTransformRef object.  This object must
	 be released with CFRelease when you are done with
	 it.  This function will return NULL if an error
	 occurred.
	 @discussion			This function creates a transform which computes a
	 decode.
	 */
	
	// See SecEncodeTransformCreate for encoding...
	__nullable
	SecTransformRef SecDecodeTransformCreate(CFTypeRef DecodeType,
											 CFErrorRef* error
											 )
	__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif


#endif
