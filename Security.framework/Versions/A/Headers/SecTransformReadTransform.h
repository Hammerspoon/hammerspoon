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

#ifndef _SEC_TRANSFORM_READ_TRANSFORM_H
#define _SEC_TRANSFORM_READ_TRANSFORM_H

#ifdef __cplusplus
extern "C" {
#endif

#include <Security/SecTransform.h>

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
	@header

			The read transform reads bytes from a instance.  The bytes are
			sent as CFDataRef instances to the OUTPUT attribute of the
			transform.
				
			This transform recognizes the following additional attributes
			that can be used to modify its behavior:
				
			MAX_READSIZE (expects CFNumber):  changes the maximum number of
			bytes the transform will attempt to read from the stream.  Note
			that the transform may deliver fewer bytes than this depending
			on the stream being used.
*/

/*!
	@function	SecTransformCreateReadTransformWithReadStream
	
	@abstract	Creates a read transform from a CFReadStreamRef
	
	@param inputStream	The stream that is to be opened and read from when
				the chain executes.
*/

SecTransformRef SecTransformCreateReadTransformWithReadStream(CFReadStreamRef inputStream)
	__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#ifdef __cplusplus
};
#endif

#endif

