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
	@header SecCode
	SecCode represents separately indentified running code in the system.
	In addition to UNIX processes, this can also include (with suitable support)
	scripts, applets, widgets, etc.
*/
#ifndef _H_SECCODE
#define _H_SECCODE

#include <Security/CSCommon.h>
#include <CoreFoundation/CFBase.h>

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@function SecCodeGetTypeID
	Returns the type identifier of all SecCode instances.
*/
CFTypeID SecCodeGetTypeID(void);


/*!
	@function SecCodeCopySelf
	Obtains a SecCode object for the code making the call.
	The calling code is determined in a way that is subject to modification over
	time, but obeys the following rules. If it is a UNIX process, its process id (pid)
	is always used. If it is an active code host that has a dedicated guest, such a guest
	is always preferred. If it is a host that has called SecHostSelectGuest, such selection
	is considered until revoked.

	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param self Upon successful return, contains a SecCodeRef representing the caller.
	
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
 */
OSStatus SecCodeCopySelf(SecCSFlags flags, SecCodeRef * __nonnull CF_RETURNS_RETAINED self);


/*!
	@function SecCodeCopyStaticCode
	Given a SecCode object, locate its origin in the file system and return
	a SecStaticCode object representing it.
	
	The link established by this call is generally reliable but is NOT guaranteed
	to be secure.
	
	Many API functions taking SecStaticCodeRef arguments will also directly
	accept a SecCodeRef and apply this translation implicitly, operating on
	its result or returning its error code if any. Each of these functions
	calls out that behavior in its documentation.
	
	If the code was obtained from a universal (aka "fat") program file,
	the resulting SecStaticCodeRef will refer only to the architecture actually
	being used. This means that multiple running codes started from the same file
	may conceivably result in different static code references if they ended up
	using different execution architectures. (This is unusual but possible.)

	@param code A valid SecCode object reference representing code running
	on the system.
	
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@constant kSecCSUseAllArchitectures
	If code refers to a single architecture of a universal binary, return a SecStaticCodeRef
	that refers to the entire universal code with all its architectures. By default, the
	returned static reference identifies only the actual architecture of the running program.

	@param staticCode On successful return, a SecStaticCode object reference representing
	the file system origin of the given SecCode. On error, unchanged.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
CF_ENUM(uint32_t) {
	kSecCSUseAllArchitectures = 1 << 0,
};

OSStatus SecCodeCopyStaticCode(SecCodeRef code, SecCSFlags flags, SecStaticCodeRef * __nonnull CF_RETURNS_RETAINED staticCode);


/*!
	@function SecCodeCopyHost
	Given a SecCode object, identify the (different) SecCode object that acts
	as its host. A SecCode's host acts as a supervisor and controller,
	and is the ultimate authority on the its dynamic validity and status.
	The host relationship is securely established (absent reported errors).
	
	@param guest A valid SecCode object reference representing code running
	on the system.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param host On successful return, a SecCode object reference identifying
	the code's host.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecCodeCopyHost(SecCodeRef guest, SecCSFlags flags, SecCodeRef * __nonnull CF_RETURNS_RETAINED host);

extern const CFStringRef kSecGuestAttributeCanonical;
extern const CFStringRef kSecGuestAttributeHash;
extern const CFStringRef kSecGuestAttributeMachPort;
extern const CFStringRef kSecGuestAttributePid;
extern const CFStringRef kSecGuestAttributeAudit;
extern const CFStringRef kSecGuestAttributeDynamicCode;
extern const CFStringRef kSecGuestAttributeDynamicCodeInfoPlist;
extern const CFStringRef kSecGuestAttributeArchitecture;
extern const CFStringRef kSecGuestAttributeSubarchitecture;

/*!
	@function SecCodeCopyGuestWithAttributes
	This is the omnibus API function for obtaining dynamic code references.
	In general, it asks a particular code acting as a code host to locate
	and return a guest with given attributes. Different hosts support
	different combinations of attributes and values for guest selection. 

	Asking the NULL host invokes system default	procedures for obtaining
	any running code in the system with the	attributes given. The returned
	code may be anywhere in the system.
 
	The methods a host uses to identify, separate, and control its guests
	are specific to each type of host. This call provides a generic abstraction layer
	that allows uniform interrogation of all hosts. A SecCode that does not
	act as a host will always return errSecCSNoSuchCode. A SecCode that does
	support hosting may return itself to signify that the attribute refers to
	itself rather than one of its hosts.
	
	@param host A valid SecCode object reference representing code running
	on the system that acts as a Code Signing host. As a special case, passing
	NULL indicates that the Code Signing root of trust should be used as a starting
	point. Currently, that is the system kernel.
	@param attributes A CFDictionary containing zero or more attribute selector
	values. Each selector has a CFString key and associated CFTypeRef value.
	The key name identifies the attribute being specified; the associated value,
	whose type depends on the the key name, selects a particular value or other
	constraint on that attribute. Each host only supports particular combinations
	of keys and values,	and errors will be returned if any unsupported set is requested.
	As a special case, NULL is taken to mean an empty attribute set.
	Note that some hosts that support hosting chains (guests being hosts)
	may return sub-guests in this call. In other words, do not assume that
	a SecCodeRef returned by this call is a direct guest of the queried host
	(though it will be a proximate guest, i.e. a guest's guest some way down).
	Asking the NULL host for NULL attributes returns a code reference for the system root
	of trust (at present, the running Darwin kernel).
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param guest On successful return, a SecCode object reference identifying
	the particular guest of the host that owns the attribute value(s) specified.
	This argument will not be changed if the call fails (does not return errSecSuccess).
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers. In particular:
	@error errSecCSUnsupportedGuestAttributes The host does not support the attribute
	type given by attributeType.
	@error errSecCSInvalidAttributeValues The type of value given for a guest
	attribute is not supported by the host.
	@error errSecCSNoSuchCode The host has no guest with the attribute value given
	by attributeValue, even though the value is of a supported type. This may also
	be returned if the host code does not currently act as a Code Signing host.
	@error errSecCSNotAHost The specified host cannot, in fact, act as a code
	host. (It is missing the kSecCodeSignatureHost option flag in its code
	signature.)
	@error errSecCSMultipleGuests The attributes specified do not uniquely identify
	a guest (the specification is ambiguous).
*/

OSStatus SecCodeCopyGuestWithAttributes(SecCodeRef __nullable host,
	CFDictionaryRef __nullable attributes,	SecCSFlags flags, SecCodeRef * __nonnull CF_RETURNS_RETAINED guest);


/*!
	@function SecCodeCheckValidity
	Performs dynamic validation of the given SecCode object. The call obtains and
	verifies the signature on the code object. It checks the validity of only those
	sealed components required to establish identity. It checks the SecCode's
	dynamic validity status as reported by its host. It ensures that the SecCode's
	host is in turn valid. Finally, it validates the code against a SecRequirement
	if one is given. The call succeeds if all these conditions are satisfactory.
	It fails otherwise.
	
	This call is secure against attempts to modify the file system source of the
	SecCode.

	@param code The code object to be validated.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param requirement An optional code requirement specifying additional conditions
	the code object must satisfy to be considered valid. If NULL, no additional
	requirements are imposed.
	@result If validation passes, errSecSuccess. If validation fails, an OSStatus value
	documented in CSCommon.h or certain other Security framework headers.
*/
OSStatus SecCodeCheckValidity(SecCodeRef code, SecCSFlags flags,
	SecRequirementRef __nullable requirement);

/*!
	@function SecCodeCheckValidityWifErrors
	Performs dynamic validation of the given SecCode object. The call obtains and
	verifies the signature on the code object. It checks the validity of only those
	sealed components required to establish identity. It checks the SecCode's
	dynamic validity status as reported by its host. It ensures that the SecCode's
	host is in turn valid. Finally, it validates the code against a SecRequirement
	if one is given. The call succeeds if all these conditions are satisfactory.
	It fails otherwise.

	This call is secure against attempts to modify the file system source of the
	SecCode.

	@param code The code object to be validated.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param requirement An optional code requirement specifying additional conditions
	the code object must satisfy to be considered valid. If NULL, no additional
	requirements are imposed.
	@param errors An optional pointer to a CFErrorRef variable. If the call fails
	(and something other than errSecSuccess is returned), and this argument is non-NULL,
	a CFErrorRef is stored there further describing the nature and circumstances
	of the failure. The caller must CFRelease() this error object when done with it.
	@result If validation passes, errSecSuccess. If validation fails, an OSStatus value
	documented in CSCommon.h or certain other Security framework headers.
*/
OSStatus SecCodeCheckValidityWithErrors(SecCodeRef code, SecCSFlags flags,
	SecRequirementRef __nullable requirement, CFErrorRef *errors);


/*!
	@function SecCodeCopyPath
	For a given Code or StaticCode object, returns a URL to a location on disk where the
	code object can be found. For single files, the URL points to that file.
	For bundles, it points to the directory containing the entire bundle.
	
	@param staticCode The Code or StaticCode object to be located. For a Code
		argument, its StaticCode is processed as per SecCodeCopyStaticCode.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param path On successful return, contains a CFURL identifying the location
	on disk of the staticCode object.
	@result On success, errSecSuccess. On error, an OSStatus value
	documented in CSCommon.h or certain other Security framework headers.
*/
OSStatus SecCodeCopyPath(SecStaticCodeRef staticCode, SecCSFlags flags,
	CFURLRef * __nonnull CF_RETURNS_RETAINED path);


/*!
	@function SecCodeCopyDesignatedRequirement
	For a given Code or StaticCode object, determines its Designated Code Requirement.
	The Designated Requirement is the SecRequirement that the code believes
	should be used to properly identify it in the future.
	
	If the SecCode contains an explicit Designated Requirement, a copy of that
	is returned. If it does not, a SecRequirement is implicitly constructed from
	its signing authority and its embedded unique identifier. No Designated
	Requirement can be obtained from code that is unsigned. Code that is modified
	after signature, improperly signed, or has become invalid, may or may not yield
	a Designated Requirement. This call does not validate the SecStaticCode argument.
	
	@param code The Code or StaticCode object to be interrogated. For a Code
		argument, its StaticCode is processed as per SecCodeCopyStaticCode.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param requirement On successful return, contains a copy of a SecRequirement
	object representing the code's Designated Requirement. On error, unchanged.
	@result On success, errSecSuccess. On error, an OSStatus value
		documented in CSCommon.h or certain other Security framework headers.
*/
OSStatus SecCodeCopyDesignatedRequirement(SecStaticCodeRef code, SecCSFlags flags,
	SecRequirementRef * __nonnull CF_RETURNS_RETAINED requirement);


/*
	@function SecCodeCopySigningInformation
	For a given Code or StaticCode object, extract various pieces of information
	from its code signature and return them in the form of a CFDictionary. The amount
	and detail level of the data is controlled by the flags passed to the call.
	
	If the code exists but is not signed at all, this call will succeed and return
	a dictionary that does NOT contain the kSecCodeInfoIdentifier key. This is the
	recommended way to check quickly whether a code is signed.
	
	If the signing data for the code is corrupt or invalid, this call may fail or it
	may return partial data. To ensure that only valid data is returned (and errors
	are raised for invalid data), you must successfully call one of the CheckValidity
	functions on the code before calling CopySigningInformation.
	
	@param code The Code or StaticCode object to be interrogated. For a Code
		argument, its StaticCode is processed as per SecCodeCopyStaticCode.
		Note that dynamic information (kSecCSDynamicInformation) cannot be obtained
		for a StaticCode argument.
	@param flags Optional flags. Use any or all of the kSecCS*Information flags
		to select what information to return. A generic set of entries is returned
		regardless; you may specify kSecCSDefaultFlags for just those.
	@param information A CFDictionary containing information about the code is stored
		here on successful completion. The contents of the dictionary depend on
		the flags passed. Regardless of flags, the kSecCodeInfoIdentifier key is
		always present if the code is signed, and always absent if the code is
		unsigned.
		Note that some of the objects returned are (retained) "live" API objects
		used by the code signing infrastructure. Making changes to these objects
		is unsupported and may cause subsequent code signing operations on the
		affected code to behave in undefined ways.
	@result On success, errSecSuccess. On error, an OSStatus value
		documented in CSCommon.h or certain other Security framework headers.
		
	Flags:
	
	@constant kSecCSSigningInformation Return cryptographic signing information,
		including the certificate chain and CMS data (if any). For ad-hoc signed
		code, there are no certificates and the CMS data is empty.
	@constant kSecCSRequirementInformation Return information about internal code
		requirements embedded in the code. This includes the Designated Requirement.
	@constant kSecCSInternalInformation Return internal code signing information.
		This information is for use by Apple, and is subject to change without notice.
		It will not be further documented here.
	@constant kSecCSDynamicInformation Return dynamic validity information about
		the Code. The subject code must be a SecCodeRef (not a SecStaticCodeRef).
	@constant kSecCSContentInformation Return more information about the file system
		contents making up the signed code on disk. It is not generally advisable to
		make use of this information, but some utilities (such as software-update
		tools) may find it useful.
	
	Dictionary keys:

	@constant kSecCodeInfoCertificates A CFArray of SecCertificates identifying the
		certificate chain of the signing certificate as seen by the system. Absent
		for ad-hoc signed code. May be partial or absent in error cases.
	@constant kSecCodeInfoChangedFiles A CFArray of CFURLs identifying all files in
		the code that may have been modified by the process of signing it. (In other
		words, files not in this list will not have been touched by the signing operation.)
	@constant kSecCodeInfoCMS A CFData containing the CMS cryptographic object that
		secures the code signature. Empty for ad-hoc signed code.
	@constant kSecCodeInfoDesignatedRequirement A SecRequirement describing the
		actual Designated Requirement of the code.
	@constant kSecCodeInfoEntitlements A CFData containing the embedded entitlement
		blob of the code, if any.
	@constant kSecCodeInfoEntitlementsDict A CFDictionary containing the embedded entitlements
		of the code if it has entitlements and they are in standard dictionary form.
		Absent if the code has no entitlements, or they are in a different format (in which
		case, see kSecCodeInfoEntitlements).
	@constant kSecCodeInfoFlags A CFNumber with the static (on-disk) state of the object.
		Contants are defined by the type SecCodeSignatureFlags.
	@constant kSecCodeInfoFormat A CFString characterizing the type and format of
		the code. Suitable for display to a (knowledeable) user.
	@constant kSecCodeInfoDigestAlgorithm A CFNumber indicating the kind of cryptographic
		hash function chosen to establish integrity of the signature on this system, which
        is the best supported algorithm from kSecCodeInfoDigestAlgorithms.
	@constant kSecCodeInfoDigestAlgorithms A CFArray of CFNumbers indicating the kinds of
 		cryptographic hash functions available within the signature. The ordering of those items
 		has no significance in terms of priority, but determines the order in which
        the hashes appear in kSecCodeInfoCdHashes.
 	@constant kSecCodeInfoPlatformIdentifier If this code was signed as part of an operating
 		system release, this value identifies that release.
	@constant kSecCodeInfoIdentifier A CFString with the actual signing identifier
		sealed into the signature. Absent for unsigned code.
	@constant kSecCodeInfoImplicitDesignatedRequirement A SecRequirement describing
		the designated requirement that the system did generate, or would have generated,
		for the code. If the Designated Requirement was implicitly generated, this is
		the same object as kSecCodeInfoDesignatedRequirement; this can be used to test
		for an explicit Designated Requirement.
	@constant kSecCodeInfoMainExecutable A CFURL identifying the main executable file
		of the code. For single files, that is the file itself. For bundles, it is the
		main executable as identified by its Info.plist.
	@constant kSecCodeInfoPList A retained CFDictionary referring to the secured Info.plist
		as seen by code signing. Absent if no Info.plist is known to the code signing
		subsystem. Note that this is not the same dictionary as the one CFBundle would
		give you (CFBundle is free to add entries to the on-disk plist).
	@constant kSecCodeInfoRequirements A CFString describing the internal requirements
		of the code in canonical syntax.
	@constant kSecCodeInfoRequirementsData A CFData containing the internal requirements
		of the code as a binary blob.
	@constant kSecCodeInfoSource A CFString describing the source of the code signature
		used for the code object. The values are meant to be shown in informational
		displays; do not rely on the precise value returned.
	@constant kSecCodeInfoStatus A CFNumber containing the dynamic status word of the
		(running) code. This is a snapshot at the time the API is executed and may be
		out of date by the time you examine it. Do note however that most of the bits
		are sticky and thus some values are permanently reliable. Be careful.
	@constant kSecCodeInfoTime A CFDate describing the signing date (securely) embedded
		in the code signature. Note that a signer is able to omit this date or pre-date
		it. Nobody certifies that this was really the date the code was signed; however,
		you do know that this is the date the signer wanted you to see.
		Ad-hoc signatures have no CMS and thus never have secured signing dates.
	@constant kSecCodeInfoTimestamp A CFDate describing the signing date as (securely)
		certified by a timestamp authority service. This time cannot be falsified by the
		signer; you trust the timestamp authority's word on this.
		Ad-hoc signatures have no CMS and thus never have secured signing dates.
	@constant kSecCodeInfoTrust The (retained) SecTrust object the system uses to
		evaluate the validity of the code's signature. You may use the SecTrust API
		to extract detailed information, particularly for reasons why certificate
		validation may have failed. This object may continue to be used for further
		evaluations of this code; if you make any changes to it, behavior is undefined.
	@constant kSecCodeInfoUnique A CFData binary identifier that uniquely identifies
		the static code in question. It can be used to recognize this particular code
		(and none other) now or in the future. Compare to kSecCodeInfoIdentifier, which
		remains stable across (developer-approved) updates.
		The algorithm used may change from time to time. However, for any existing signature,
 		the value is stable.
	@constant kSecCodeInfoCdHashes An array containing the values of the kSecCodeInfoUnique
        binary identifier for every digest algorithm supported in the signature, in the same
        order as in the kSecCodeInfoDigestAlgorithms array. The kSecCodeInfoUnique value
        will be contained in this array, and be the one corresponding to the
        kSecCodeInfoDigestAlgorithm value.
 */
CF_ENUM(uint32_t) {
	kSecCSInternalInformation = 1 << 0,
	kSecCSSigningInformation = 1 << 1,
	kSecCSRequirementInformation = 1 << 2,
	kSecCSDynamicInformation = 1 << 3,
	kSecCSContentInformation = 1 << 4
};
													/* flag required to get this value */
extern const CFStringRef kSecCodeInfoCertificates;	/* Signing */
extern const CFStringRef kSecCodeInfoChangedFiles;	/* Content */
extern const CFStringRef kSecCodeInfoCMS;			/* Signing */
extern const CFStringRef kSecCodeInfoDesignatedRequirement; /* Requirement */
extern const CFStringRef kSecCodeInfoEntitlements;	/* Requirement */
extern const CFStringRef kSecCodeInfoEntitlementsDict; /* Requirement */
extern const CFStringRef kSecCodeInfoFlags;		/* generic */
extern const CFStringRef kSecCodeInfoFormat;		/* generic */
extern const CFStringRef kSecCodeInfoDigestAlgorithm; /* generic */
extern const CFStringRef kSecCodeInfoDigestAlgorithms; /* generic */
extern const CFStringRef kSecCodeInfoPlatformIdentifier; /* generic */
extern const CFStringRef kSecCodeInfoIdentifier;	/* generic */
extern const CFStringRef kSecCodeInfoImplicitDesignatedRequirement; /* Requirement */
extern const CFStringRef kSecCodeInfoMainExecutable; /* generic */
extern const CFStringRef kSecCodeInfoPList;			/* generic */
extern const CFStringRef kSecCodeInfoRequirements;	/* Requirement */
extern const CFStringRef kSecCodeInfoRequirementData; /* Requirement */
extern const CFStringRef kSecCodeInfoSource;		/* generic */
extern const CFStringRef kSecCodeInfoStatus;		/* Dynamic */
extern const CFStringRef kSecCodeInfoTeamIdentifier; /* Signing */
extern const CFStringRef kSecCodeInfoTime;			/* Signing */
extern const CFStringRef kSecCodeInfoTimestamp;		/* Signing */
extern const CFStringRef kSecCodeInfoTrust;			/* Signing */
extern const CFStringRef kSecCodeInfoUnique;		/* generic */
extern const CFStringRef kSecCodeInfoCdHashes;		/* generic */

OSStatus SecCodeCopySigningInformation(SecStaticCodeRef code, SecCSFlags flags,
	CFDictionaryRef * __nonnull CF_RETURNS_RETAINED information);


/*
	@function SecCodeMapMemory
	For a given Code or StaticCode object, ask the kernel to accept the signing information
	currently attached to it in the caller and use it to validate memory page-ins against it,
	updating dynamic validity state accordingly. This change affects all processes that have
	the main executable of this code mapped.
	
	@param code A Code or StaticCode object representing the signed code whose main executable
		should be subject to page-in validation.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
 */
OSStatus SecCodeMapMemory(SecStaticCodeRef code, SecCSFlags flags);

CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif //_H_SECCODE
