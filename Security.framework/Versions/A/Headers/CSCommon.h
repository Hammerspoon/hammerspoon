/*
 * Copyright (c) 2006-2014 Apple Inc. All Rights Reserved.
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
	@header CSCommon
	CSCommon is the common header of all Code Signing API headers.
	It defines types, constants, and error codes.
*/
#ifndef _H_CSCOMMON
#define _H_CSCOMMON

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>

CF_ASSUME_NONNULL_BEGIN

/*
	Code Signing specific OSStatus codes.
	[Assigned range 0xFFFE_FAxx].
*/
CF_ENUM(OSStatus) {
	errSecCSUnimplemented =				-67072,	/* unimplemented code signing feature */
	errSecCSInvalidObjectRef =			-67071,	/* invalid API object reference */
	errSecCSInvalidFlags =				-67070,	/* invalid or inappropriate API flag(s) specified */
	errSecCSObjectRequired =			-67069,	/* a required pointer argument was NULL */
	errSecCSStaticCodeNotFound =		-67068,	/* cannot find code object on disk */
	errSecCSUnsupportedGuestAttributes = -67067, /* cannot locate guests using this attribute set */
	errSecCSInvalidAttributeValues =	-67066,	/* given attribute values are invalid */
	errSecCSNoSuchCode =				-67065,	/* host has no guest with the requested attributes */
	errSecCSMultipleGuests =			-67064,	/* ambiguous guest specification (host has multiple guests with these attribute values) */
	errSecCSGuestInvalid =				-67063,	/* code identity has been invalidated */
	errSecCSUnsigned =					-67062,	/* code object is not signed at all */
	errSecCSSignatureFailed =			-67061,	/* invalid signature (code or signature have been modified) */
	errSecCSSignatureNotVerifiable =	-67060,	/* the code cannot be read by the verifier (file system permissions etc.) */
	errSecCSSignatureUnsupported =		-67059,	/* unsupported type or version of signature */
	errSecCSBadDictionaryFormat =		-67058,	/* a required plist file or resource is malformed */
	errSecCSResourcesNotSealed =		-67057,	/* resources are present but not sealed by signature */
	errSecCSResourcesNotFound =			-67056,	/* code has no resources but signature indicates they must be present */
	errSecCSResourcesInvalid =			-67055,	/* the sealed resource directory is invalid */
	errSecCSBadResource =				-67054,	/* a sealed resource is missing or invalid */
	errSecCSResourceRulesInvalid =		-67053,	/* invalid resource specification rule(s) */
	errSecCSReqInvalid =				-67052,	/* invalid or corrupted code requirement(s) */
	errSecCSReqUnsupported =			-67051,	/* unsupported type or version of code requirement(s) */
	errSecCSReqFailed =					-67050,	/* code failed to satisfy specified code requirement(s) */
	errSecCSBadObjectFormat =			-67049,	/* object file format unrecognized, invalid, or unsuitable */
	errSecCSInternalError =				-67048,	/* internal error in Code Signing subsystem */
	errSecCSHostReject =				-67047,	/* code rejected its host */
	errSecCSNotAHost =					-67046,	/* attempt to specify guest of code that is not a host */
	errSecCSSignatureInvalid =			-67045,	/* invalid or unsupported format for signature */
	errSecCSHostProtocolRelativePath =	-67044, /* host protocol violation - absolute guest path required */
	errSecCSHostProtocolContradiction =	-67043,	/* host protocol violation - contradictory hosting modes */
	errSecCSHostProtocolDedicationError = -67042, /* host protocol violation - operation not allowed with/for a dedicated guest */
	errSecCSHostProtocolNotProxy =		-67041,	/* host protocol violation - proxy hosting not engaged */
	errSecCSHostProtocolStateError =	-67040,	/* host protocol violation - invalid guest state change request */
	errSecCSHostProtocolUnrelated =		-67039,	/* host protocol violation - the given guest is not a guest of the given host */
									 /* -67038 obsolete (no longer issued) */
	errSecCSNotSupported =				-67037,	/* operation inapplicable or not supported for this type of code */
	errSecCSCMSTooLarge =				-67036,	/* signature too large to embed (size limitation of on-disk representation) */
	errSecCSHostProtocolInvalidHash =	-67035,	/* host protocol violation - invalid guest hash */
	errSecCSStaticCodeChanged =			-67034,	/* the code on disk does not match what is running */
	errSecCSDBDenied =					-67033,	/* permission to use a database denied */
	errSecCSDBAccess =					-67032,	/* cannot access a database */
	errSecCSSigDBDenied = errSecCSDBDenied,
	errSecCSSigDBAccess = errSecCSDBAccess,
	errSecCSHostProtocolInvalidAttribute = -67031, /* host returned invalid or inconsistent guest attributes */
	errSecCSInfoPlistFailed =			-67030,	/* invalid Info.plist (plist or signature have been modified) */
	errSecCSNoMainExecutable =			-67029,	/* the code has no main executable file */
	errSecCSBadBundleFormat =			-67028,	/* bundle format unrecognized, invalid, or unsuitable */
	errSecCSNoMatches =					-67027,	/* no matches for search or update operation */
	errSecCSFileHardQuarantined =		-67026,	/* File created by an AppSandbox, exec/open not allowed */
	errSecCSOutdated =					-67025,	/* presented data is out of date */
	errSecCSDbCorrupt =					-67024,	/* a system database or file is corrupt */
	errSecCSResourceDirectoryFailed =	-67023,	/* invalid resource directory (directory or signature have been modified) */
	errSecCSUnsignedNestedCode =		-67022,	/* nested code is unsigned */
	errSecCSBadNestedCode =				-67021,	/* nested code is modified or invalid */
	errSecCSBadCallbackValue =			-67020,	/* monitor callback returned invalid value */
	errSecCSHelperFailed =				-67019,	/* the codesign_allocate helper tool cannot be found or used */
	errSecCSVetoed =					-67018,
	errSecCSBadLVArch =					-67017, /* library validation flag cannot be used with an i386 binary */
	errSecCSResourceNotSupported =		-67016, /* unsupported resource found (something not a directory, file or symlink) */
	errSecCSRegularFile =				-67015, /* the main executable or Info.plist must be a regular file (no symlinks, etc.) */
	errSecCSUnsealedAppRoot	=			-67014, /* unsealed contents present in the bundle root */
	errSecCSWeakResourceRules =			-67013, /* resource envelope is obsolete (custom omit rules) */
	errSecCSDSStoreSymlink =			-67012, /* .DS_Store files cannot be a symlink */ 
	errSecCSAmbiguousBundleFormat =		-67011, /* bundle format is ambiguous (could be app or framework) */
	errSecCSBadMainExecutable =			-67010, /* main executable failed strict validation */
	errSecCSBadFrameworkVersion = 		-67009, /* embedded framework contains modified or invalid version */
	errSecCSUnsealedFrameworkRoot =		-67008, /* unsealed contents present in the root directory of an embedded framework */
	errSecCSWeakResourceEnvelope =		-67007, /* resource envelope is obsolete (version 1 signature) */
	errSecCSCancelled =					-67006, /* operation was terminated by explicit cancellation */
	errSecCSInvalidPlatform =			-67005,	/* invalid platform identifier or platform mismatch */
	errSecCSTooBig =					-67004,	/* code is too big for current signing format */
	errSecCSInvalidSymlink =			-67003,	/* invalid destination for symbolic link in bundle */
	errSecCSNotAppLike =				-67002,	/* the code is valid but does not seem to be an app */
	errSecCSBadDiskImageFormat =		-67001,	/* disk image format unrecognized, invalid, or unsuitable */
	errSecCSUnsupportedDigestAlgorithm = -67000, /* signature digest algorithm(s) specified are not supported */
	errSecCSInvalidAssociatedFileData =	-66999,	/* resource fork, Finder information, or similar detritus not allowed */
    errSecCSInvalidTeamIdentifier =     -66998, /* a Team Identifier string is invalid */
    errSecCSBadTeamIdentifier =         -66997, /* a Team Identifier is wrong or inappropriate */
};

/*
 * Code Signing specific CFError "user info" keys.
 * In calls that can return CFErrorRef indications, if a CFErrorRef is actually
 * returned, its "user info" dictionary may contain some of the following keys
 * to more closely describe the circumstances of the failure.
 * Do not rely on the presence of any particular key to categorize a problem;
 * always use the primary OSStatus return for that. The data contained under
 * these keys is always supplemental and optional.
 */
extern const CFStringRef kSecCFErrorArchitecture;	/* CFStringRef: name of architecture causing the problem */
extern const CFStringRef kSecCFErrorPattern;		/* CFStringRef: invalid resource selection pattern encountered */
extern const CFStringRef kSecCFErrorResourceSeal;	/* CFTypeRef: invalid component in resource seal (CodeResources) */
extern const CFStringRef kSecCFErrorResourceAdded;	/* CFURLRef: unsealed resource found */
extern const CFStringRef kSecCFErrorResourceAltered; /* CFURLRef: modified resource found */
extern const CFStringRef kSecCFErrorResourceMissing; /* CFURLRef: sealed (non-optional) resource missing */
extern const CFStringRef kSecCFErrorResourceSideband; /* CFURLRef: sealed resource has invalid sideband data (resource fork, etc.) */
extern const CFStringRef kSecCFErrorInfoPlist;		/* CFTypeRef: Info.plist dictionary or component thereof found invalid */
extern const CFStringRef kSecCFErrorGuestAttributes; /* CFTypeRef: Guest attribute set of element not accepted */
extern const CFStringRef kSecCFErrorRequirementSyntax; /* CFStringRef: compilation error for Requirement source */
extern const CFStringRef kSecCFErrorPath;			/* CFURLRef: subcomponent containing the error */

/*!
	@typedef SecCodeRef
	This is the type of a reference to running code.

	In many (but not all) calls, this can be passed to a SecStaticCodeRef
	argument, which performs an implicit SecCodeCopyStaticCode call and
	operates on the result.
*/
typedef struct CF_BRIDGED_TYPE(id) __SecCode *SecCodeRef;	/* running code */

/*!
	@typedef SecStaticCodeRef
	This is the type of a reference to static code on disk.
*/
typedef struct CF_BRIDGED_TYPE(id) __SecCode const *SecStaticCodeRef;	/* code on disk */

/*!
	@typedef SecRequirementRef
	This is the type of a reference to a code requirement.
*/
typedef struct CF_BRIDGED_TYPE(id) __SecRequirement *SecRequirementRef;	/* code requirement */


/*!
	@typedef SecGuestRef
	An abstract handle to identify a particular Guest in the context of its Host.
	
	Guest handles are assigned by the host at will, with kSecNoGuest (zero) being
	reserved as the null value. They can be reused for new children if desired.
*/
typedef u_int32_t SecGuestRef;

CF_ENUM(SecGuestRef) {
	kSecNoGuest = 0,		/* not a valid SecGuestRef */
};


/*!
	@typedef SecCSFlags
	This is the type of flags arguments to Code Signing API calls.
	It provides a bit mask of request and option flags. All of the bits in these
	masks are reserved to Apple; if you set any bits not defined in these headers,
	the behavior is generally undefined.
	
	This list describes the flags that are shared among several Code Signing API calls.
	Flags that only apply to one call are defined and documented with that call.
	Global flags are assigned from high order down (31 -> 0); call-specific flags
	are assigned from the bottom up (0 -> 31).

	@constant kSecCSDefaultFlags
	When passed to a flags argument throughout, indicates that default behavior
	is desired. Do not mix with other flags values.
	@constant kSecCSConsiderExpiration
	When passed to a call that performs code validation, requests that code signatures
	made by expired certificates be rejected. By default, expiration of participating
	certificates is not automatic grounds for rejection.
*/
typedef CF_OPTIONS(uint32_t, SecCSFlags) {
    kSecCSDefaultFlags = 0,					/* no particular flags (default behavior) */
	
    kSecCSConsiderExpiration = 1U << 31,		/* consider expired certificates invalid */
    kSecCSEnforceRevocationChecks = 1 << 30,	/* force revocation checks regardless of preference settings */
    kSecCSNoNetworkAccess = 1 << 29,            /* do not use the network, cancels "kSecCSEnforceRevocationChecks"  */
	kSecCSReportProgress = 1 << 28,			/* make progress report call-backs when configured */
    kSecCSCheckTrustedAnchors = 1 << 27, /* build certificate chain to system trust anchors, not to any self-signed certificate */
	kSecCSQuickCheck = 1 << 26,		/* (internal) */
};


/*!
	@typedef SecCodeSignatureFlags
	This is the type of option flags that can be embedded in a code signature
	during signing, and that govern the use of the signature thereafter.
	Some of these flags can be set through the codesign(1) command's --options
	argument; some are set implicitly based on signing circumstances; and all
	can be set with the kSecCodeSignerFlags item of a signing information dictionary.
	
	@constant kSecCodeSignatureHost
	Indicates that the code may act as a host that controls and supervises guest
	code. If this flag is not set in a code signature, the code is never considered
	eligible to be a host, and any attempt to act like one will be ignored or rejected.
	@constant kSecCodeSignatureAdhoc
	The code has been sealed without a signing identity. No identity may be retrieved
	from it, and any code requirement placing restrictions on the signing identity
	will fail. This flag is set by the code signing API and cannot be set explicitly.
	@constant kSecCodeSignatureForceHard
	Implicitly set the "hard" status bit for the code when it starts running.
	This bit indicates that the code prefers to be denied access to a resource
	if gaining such access would cause its invalidation. Since the hard bit is
	sticky, setting this option bit guarantees that the code will always have
	it set.
	@constant kSecCodeSignatureForceKill
	Implicitly set the "kill" status bit for the code when it starts running.
	This bit indicates that the code wishes to be terminated with prejudice if
	it is ever invalidated. Since the kill bit is sticky, setting this option bit
	guarantees that the code will always be dynamically valid, since it will die
	immediately	if it becomes invalid.
	@constant kSecCodeSignatureForceExpiration
	Forces the kSecCSConsiderExpiration flag on all validations of the code.
 */
typedef CF_OPTIONS(uint32_t, SecCodeSignatureFlags) {
	kSecCodeSignatureHost = 0x0001,			/* may host guest code */
	kSecCodeSignatureAdhoc = 0x0002,		/* must be used without signer */
	kSecCodeSignatureForceHard = 0x0100,	/* always set HARD mode on launch */
	kSecCodeSignatureForceKill = 0x0200,	/* always set KILL mode on launch */
	kSecCodeSignatureForceExpiration = 0x0400, /* force certificate expiration checks */
	kSecCodeSignatureRestrict = 0x0800, /* restrict dyld loading */
	kSecCodeSignatureEnforcement = 0x1000, /* enforce code signing */
	kSecCodeSignatureLibraryValidation = 0x2000, /* library validation required */
};


/*!
	@typedef SecCodeStatus
	The code signing system attaches a set of status flags to each running code.
	These flags are maintained by the code's host, and can be read by anyone.
	A code may change its own flags, a host may change its guests' flags,
	and root may change anyone's flags.	However, these flags are sticky in that
	each can change in only one direction (and never back, for the lifetime of the code).
	Not even root can violate this restriction.

	There are other flags in SecCodeStatus that are not publicly documented.
	Do not rely on them, and do not ever attempt to explicitly set them.

	@constant kSecCodeStatusValid
	Indicates that the code is dynamically valid, i.e. it started correctly
	and has not been invalidated since then. The valid bit can only be cleared.
	
	Warning: This bit is not your one-stop shortcut to determining the validity	of code.
	It represents the dynamic component of the full validity function; if this
	bit is unset, the code is definitely invalid, but the converse is not always true.
	In fact, code hosts may represent the outcome of some delayed static validation work in this bit,
	and thus it strictly represents a blend of (all of) dynamic and (some of) static validity,
	depending on the implementation of the particular host managing the code. You can (only)
	rely that (1) dynamic invalidation will clear this bit; and (2) the combination
	of static validation and dynamic validity (as performed by the SecCodeCheckValidity* APIs)
	will give a correct answer.
	
	@constant kSecCodeStatusHard
	Indicates that the code prefers to be denied access to resources if gaining access
	would invalidate it. This bit can only be set.
	It is undefined whether code that is marked hard and is already invalid will still
	be denied access to a resource that would invalidate it if it were still valid. That is,
	the code may or may not get access to such a resource while being invalid, and that choice
	may appear random.
	
	@constant kSecCodeStatusKill
	Indicates that the code wants to be killed (terminated) if it ever loses its validity.
	This bit can only be set. Code that has the kill flag set will never be dynamically invalid
	(and live). Note however that a change in static validity does not necessarily trigger instant
	death.
*/
typedef CF_OPTIONS(uint32_t, SecCodeStatus) {
	kSecCodeStatusValid =	0x0001,
	kSecCodeStatusHard =	0x0100,
	kSecCodeStatusKill =	0x0200,
};


/*!
	@typedef SecRequirementType
	An enumeration indicating different types of internal requirements for code.
 */
typedef CF_ENUM(uint32_t, SecRequirementType) {
	kSecHostRequirementType =			1,	/* what hosts may run us */
	kSecGuestRequirementType =			2,	/* what guests we may run */
	kSecDesignatedRequirementType =		3,	/* designated requirement */
	kSecLibraryRequirementType =		4,	/* what libraries we may link against */
	kSecPluginRequirementType =			5,	/* what plug-ins we may load */
	kSecInvalidRequirementType,				/* invalid type of Requirement (must be last) */
	kSecRequirementTypeCount = kSecInvalidRequirementType /* number of valid requirement types */
};
	
	
/*!
 Types of cryptographic digests (hashes) used to hold code signatures
 together.
 
 Each combination of type, length, and other parameters is a separate
 hash type; we don't understand "families" here.
 
 These type codes govern the digest links that connect a CodeDirectory
 to its subordinate data structures (code pages, resources, etc.)
 They do not directly control other uses of hashes (such as those used
 within X.509 certificates and CMS blobs).
 */
typedef CF_ENUM(uint32_t, SecCSDigestAlgorithm) {
	kSecCodeSignatureNoHash							=  0,	/* null value */
	kSecCodeSignatureHashSHA1						=  1,	/* SHA-1 */
	kSecCodeSignatureHashSHA256						=  2,	/* SHA-256 */
	kSecCodeSignatureHashSHA256Truncated			=  3,	/* SHA-256 truncated to first 20 bytes */
	kSecCodeSignatureHashSHA384						=  4,	/* SHA-384 */
};

CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif //_H_CSCOMMON
