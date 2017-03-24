/*
 * Copyright (c) 2002-2004,2011-2012,2014 Apple Inc. All Rights Reserved.
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
	@header SecTrustedApplication
	The functions provided in SecTrustedApplication implement an object representing an application in a
	SecAccess object.
*/

#ifndef _SECURITY_SECTRUSTEDAPPLICATION_H_
#define _SECURITY_SECTRUSTEDAPPLICATION_H_

#include <Security/SecBase.h>
#include <CoreFoundation/CoreFoundation.h>


#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@function SecTrustedApplicationGetTypeID
	@abstract Returns the type identifier of SecTrustedApplication instances.
	@result The CFTypeID of SecTrustedApplication instances.
*/
CFTypeID SecTrustedApplicationGetTypeID(void);

/*!
	@function SecTrustedApplicationCreateFromPath
    @abstract Creates a trusted application reference based on the trusted application specified by path.
    @param path The path to the application or tool to trust. For application bundles, use the
		path to the bundle directory. Pass NULL to refer to yourself, i.e. the application or tool
		making this call.
    @param app On return, a pointer to the trusted application reference.
    @result A result code.  See "Security Error Codes" (SecBase.h).
*/
OSStatus SecTrustedApplicationCreateFromPath(const char * __nullable path, SecTrustedApplicationRef * __nonnull CF_RETURNS_RETAINED app);

/*!
	@function SecTrustedApplicationCopyData
	@abstract Retrieves the data of a given trusted application reference
	@param appRef A trusted application reference to retrieve data from
	@param data On return, a pointer to a data reference of the trusted application.
	@result A result code.  See "Security Error Codes" (SecBase.h).
*/
OSStatus SecTrustedApplicationCopyData(SecTrustedApplicationRef appRef, CFDataRef * __nonnull CF_RETURNS_RETAINED data);

/*!
	@function SecTrustedApplicationSetData
	@abstract Sets the data of a given trusted application reference
	@param appRef A trusted application reference.
	@param data A reference to the data to set in the trusted application.
	@result A result code.  See "Security Error Codes" (SecBase.h).
*/
OSStatus SecTrustedApplicationSetData(SecTrustedApplicationRef appRef, CFDataRef data);

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECTRUSTEDAPPLICATION_H_ */
