/*
 * Copyright (c) 2006,2011-2014 Apple Inc. All Rights Reserved.
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
	@header SecStaticCode
	SecStaticCode represents the Code Signing identity of code in the file system.
	This includes applications, tools, frameworks, plugins,	scripts, and so on.
	Note that arbitrary files will be considered scripts of unknown provenance;
	and thus it is possible to handle most files as if they were code, though that is
	not necessarily a good idea.
	
	Normally, each SecCode has a specific SecStaticCode that holds its static signing
	data. Informally, that is the SecStaticCode the SecCode "was made from" (by its host).
	There is however no viable link in the other direction - given a SecStaticCode,
	it is not possible to find, enumerate, or control any SecCode that originated from it.
	There might not be any at a given point in time; or there might be many.
*/
#ifndef _H_SECSTATICCODE
#define _H_SECSTATICCODE

#include <Security/CSCommon.h>

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@function SecStaticCodeGetTypeID
	Returns the type identifier of all SecStaticCode instances.
*/
CFTypeID SecStaticCodeGetTypeID(void);


/*!
	@function SecStaticCodeCreateWithPath
	Given a path to a file system object, create a SecStaticCode object representing
	the code at that location, if possible. Such a SecStaticCode is not inherently
	linked to running code in the system.
	
	It is possible to create a SecStaticCode object from an unsigned code object.
	Most uses of such an object will return the errSecCSUnsigned error. However,
	SecCodeCopyPath and SecCodeCopySigningInformation can be safely applied to such objects.

	@param path A path to a location in the file system. Only file:// URLs are
	currently supported. For bundles, pass a URL to the root directory of the
	bundle. For single files, pass a URL to the file. If you pass a URL to the
	main executable of a bundle, the bundle as a whole will be generally recognized.
	Caution: Paths containing embedded // or /../ within a bundle's directory
	may cause the bundle to be misconstrued. If you expect to submit such paths,
	first clean them with realpath(3) or equivalent.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param staticCode On successful return, contains a reference to the StaticCode object
	representing the code at path. Unchanged on error.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecStaticCodeCreateWithPath(CFURLRef path, SecCSFlags flags, SecStaticCodeRef * __nonnull CF_RETURNS_RETAINED staticCode);

extern const CFStringRef kSecCodeAttributeArchitecture;
extern const CFStringRef kSecCodeAttributeSubarchitecture;
extern const CFStringRef kSecCodeAttributeUniversalFileOffset;
extern const CFStringRef kSecCodeAttributeBundleVersion;

/*!
	@function SecStaticCodeCreateWithPathAndAttributes
	Given a path to a file system object, create a SecStaticCode object representing
	the code at that location, if possible. Such a SecStaticCode is not inherently
	linked to running code in the system.
	
	It is possible to create a SecStaticCode object from an unsigned code object.
	Most uses of such an object will return the errSecCSUnsigned error. However,
	SecCodeCopyPath and SecCodeCopySigningInformation can be safely applied to such objects.

	@param path A path to a location in the file system. Only file:// URLs are
	currently supported. For bundles, pass a URL to the root directory of the
	bundle. For single files, pass a URL to the file. If you pass a URL to the
	main executable of a bundle, the bundle as a whole will be generally recognized.
	Caution: Paths containing embedded // or /../ within a bundle's directory
	may cause the bundle to be misconstrued. If you expect to submit such paths,
	first clean them with realpath(3) or equivalent.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param attributes A CFDictionary containing additional attributes of the code sought.
	@param staticCode On successful return, contains a reference to the StaticCode object
	representing the code at path. Unchanged on error.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.

	@constant kSecCodeAttributeArchitecture Specifies the Mach-O architecture of code desired.
	This can be a CFString containing a canonical architecture name ("i386" etc.), or a CFNumber
	specifying an architecture numerically (see mach/machine.h). This key is ignored if the code
	is not in Mach-O binary form. If the code is Mach-O but not universal ("thin"), the architecture
	specified must agree with the actual file contents.
	@constant kSecCodeAttributeSubarchitecture If the architecture is specified numerically
	(using the kSecCodeAttributeArchitecture key), specifies any sub-architecture by number.
	This key is ignored if no main architecture is specified; if it is specified by name; or
	if the code is not in Mach-O form.
	@constant kSecCodeAttributeUniversalFileOffset The offset of a Mach-O specific slice of a universal Mach-O file.
*/
OSStatus SecStaticCodeCreateWithPathAndAttributes(CFURLRef path, SecCSFlags flags, CFDictionaryRef attributes,
	SecStaticCodeRef * __nonnull CF_RETURNS_RETAINED staticCode);


/*!
	@function SecStaticCodeCheckValidity
	Performs static validation on the given SecStaticCode object. The call obtains and
	verifies the signature on the code object. It checks the validity of all
	sealed components (including resources, if any). It validates the code against
	a SecRequirement if one is given. The call succeeds if all these conditions
	are satisfactory. It fails otherwise.
	
	This call is only secure if the code is not subject to concurrent modification,
	and the outcome is only valid as long as the code is unmodified thereafter.
	Consider this carefully if the underlying file system has dynamic characteristics,
	such as a network file system, union mount, FUSE, etc.

	@param staticCode The code object to be validated.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	
	@constant kSecCSCheckAllArchitectures
	For multi-architecture (universal) Mach-O programs, validate all architectures
	included. By default, only the native architecture is validated.
	@constant kSecCSNoDnotValidateExecutable
	Do not validate the contents of the main executable. This is normally done.
	@constant kSecCSNoNotValidateResources
	Do not validate the presence and contents of all bundle resources (if any).
	By default, a mismatch in any bundle resource causes validation to fail.
	@constant kSecCSCheckNestedCode
	For code in bundle form, locate and recursively check embedded code. Only code
	in standard locations is considered.
	@constant kSecCSStrictValidate
	For code in bundle form, perform additional checks to verify that the bundle
	is not structured in a way that would allow tampering, and reject any resource
	envelope that introduces weaknesses into the signature.
	
	@param requirement On optional code requirement specifying additional conditions
	the staticCode object must satisfy to be considered valid. If NULL, no additional
	requirements are imposed.
	@param errors An optional pointer to a CFErrorRef variable. If the call fails
	(something other than errSecSuccess is returned), and this argument is non-NULL,
	a CFErrorRef is stored there further describing the nature and circumstances
	of the failure. The caller must CFRelease() this error object when done with it.
	@result If validation succeeds, errSecSuccess. If validation fails, an OSStatus value
	documented in CSCommon.h or certain other Security framework headers.
*/
CF_ENUM(uint32_t) {
	kSecCSCheckAllArchitectures = 1 << 0,
	kSecCSDoNotValidateExecutable = 1 << 1,
	kSecCSDoNotValidateResources = 1 << 2,
	kSecCSBasicValidateOnly = kSecCSDoNotValidateExecutable | kSecCSDoNotValidateResources,
	kSecCSCheckNestedCode = 1 << 3,
	kSecCSStrictValidate = 1 << 4,
	kSecCSFullReport = 1 << 5,
	kSecCSCheckGatekeeperArchitectures = (1 << 6) | kSecCSCheckAllArchitectures,
	kSecCSRestrictSymlinks = 1 << 7,
	kSecCSRestrictToAppLike = 1 << 8,
	kSecCSRestrictSidebandData = 1 << 9,
};

OSStatus SecStaticCodeCheckValidity(SecStaticCodeRef staticCode, SecCSFlags flags,
	SecRequirementRef __nullable requirement);

OSStatus SecStaticCodeCheckValidityWithErrors(SecStaticCodeRef staticCode, SecCSFlags flags,
	SecRequirementRef __nullable requirement, CFErrorRef *errors);

CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif //_H_SECSTATICCODE
