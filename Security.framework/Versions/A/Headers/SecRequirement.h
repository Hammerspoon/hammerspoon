/*
 * Copyright (c) 2006,2011,2013-2014 Apple Inc. All Rights Reserved.
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
	@header SecRequirement
	SecRequirement represents a condition or constraint (a "Code Requirement")
	that code must satisfy to be considered valid for some purpose.
	SecRequirement itself does not understand or care WHY such a constraint
	is appropriate or useful; it is	purely a tool for formulating, recording,
	and evaluating it.
	
	Code Requirements are usually stored and retrieved in the form of a variable-length
	binary Blob that can be encapsulated as a CFDataRef and safely stored in various
	data structures. They can be formulated in a text form that can be compiled
	into binary form and decompiled back into text form without loss of functionality
	(though comments and formatting are not preserved).
*/
#ifndef _H_SECREQUIREMENT
#define _H_SECREQUIREMENT

#include <Security/CSCommon.h>
#include <Security/SecCertificate.h>

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@function SecRequirementGetTypeID
	Returns the type identifier of all SecRequirement instances.
*/
CFTypeID SecRequirementGetTypeID(void);


/*!
	@function SecRequirementCreateWithData
	Create a SecRequirement object from binary form.
	This is the effective inverse of SecRequirementCopyData.
	
	@param data A binary blob obtained earlier from a valid SecRequirement object
	using the SecRequirementCopyData call. This is the only publicly supported
	way to get such a data blob.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param requirement On successful return, contains a reference to a SecRequirement
	object that behaves identically to the one the data blob was obtained from.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecRequirementCreateWithData(CFDataRef data, SecCSFlags flags,
	SecRequirementRef * __nonnull CF_RETURNS_RETAINED requirement);

	
/*!
	@function SecRequirementCreateWithString
	Create a SecRequirement object by compiling a valid text representation
	of a requirement.
	
	@param text A CFString containing the text form of a (single) Code Requirement.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param requirement On successful return, contains a reference to a SecRequirement
	object that implements the conditions described in text.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecRequirementCreateWithString(CFStringRef text, SecCSFlags flags,
	SecRequirementRef * __nonnull CF_RETURNS_RETAINED requirement);
	
OSStatus SecRequirementCreateWithStringAndErrors(CFStringRef text, SecCSFlags flags,
	CFErrorRef *errors, SecRequirementRef * __nonnull CF_RETURNS_RETAINED requirement);


/*!
	@function SecRequirementCopyData
	Extracts a stable, persistent binary form of a SecRequirement.
	This is the effective inverse of SecRequirementCreateWithData.
	
	@param requirement A valid SecRequirement object.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param data On successful return, contains a reference to a CFData object
	containing a binary blob that can be fed to SecRequirementCreateWithData
	to recreate a SecRequirement object with identical behavior.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecRequirementCopyData(SecRequirementRef requirement, SecCSFlags flags,
	CFDataRef * __nonnull CF_RETURNS_RETAINED data);


/*!
	@function SecRequirementCopyString
	Converts a SecRequirement object into text form.
	This is the effective inverse of SecRequirementCreateWithString.
	
	Repeated application of this function may produce text that differs in
	formatting, may contain different source comments, and may perform its
	validation functions in different order. However, it is guaranteed that
	recompiling the text using SecRequirementCreateWithString will produce a
	SecRequirement object that behaves identically to the one you start with.
	
	@param requirement A valid SecRequirement object.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param text On successful return, contains a reference to a CFString object
	containing a text representation of the requirement.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecRequirementCopyString(SecRequirementRef requirement, SecCSFlags flags,
	CFStringRef * __nonnull CF_RETURNS_RETAINED text);

CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif //_H_SECREQUIREMENT
