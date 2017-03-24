/*
 * Copyright (c) 2006-2007,2011,2013 Apple Inc. All Rights Reserved.
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
	@header SecCodeHost
	This header provides the hosting API for Code Signing. These are calls
	that are (only) made by code that is hosting guests.
	In the context of Code Signing, a Host is code that creates and manages other
	codes from which it defends its own integrity. As part of that duty, it maintains
	state for each of its children, and answers questions about them.

	A Host is externally represented by a SecCodeRef (it is a SecCode object).
	So is a Guest. There is no specific API object to represent Hosts or Guests.
	Within the Hosting API, guests are identified by simple numeric handles that
	are unique and valid only in the context of their specific host.

	The functions in this API always apply to the Host making the API calls.
	They cannot be used to (directly) interrogate another host.
*/
#ifndef _H_SECCODEHOST
#define _H_SECCODEHOST

#include <Security/CSCommon.h>

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@header SecCodeHost
	This header describes the Code Signing Hosting API. These are calls made
	by code that wishes to become a Host in the Code Signing Host/Guest infrastructure.
	Hosting allows the caller to establish separate, independent code identities
	(SecCodeRefs) for parts of itself, usually because it is loading and managing
	code in the form of scripts, plugins, etc.
	
	The Hosting API does not directly connect to the Code Signing Client APIs.
	Certain calls in the client API will cause internal queries to hosts about their
	guests. The Host side of these queries is managed through this API. The results
	will eventually be delivered to client API callers in appropriate form.
	
	If code never calls any of the Hosting API functions, it is deemed to not have
	guests and not act as a Host. This is the default and requires no action.

	Hosting operates in one of two modes, dynamic or proxy. Whichever mode is first
	engaged prevails for the lifetime of the caller. There is no way to switch between
	the two, and calling an API belonging to the opposite mode will fail.
	
	In dynamic hosting mode, the caller provides a Mach port that receives direct
	queries about its guests. Dynamic mode is engaged by calling SecHostSetHostingPort.
	
	In proxy hosting mode, the caller provides information about its guests as
	guests are created, removed, or change status. The system caches this information
	and answers queries about guests from this pool of information. The caller is not
	directly involved in answering such queries, and has no way to intervene.
*/


/*!
	@function SecHostCreateGuest
	Create a new Guest and describe its initial properties.
	
	This call activates Hosting Proxy Mode. From here on, the system will record
	guest information provided through SecHostCreateGuest, SecHostSetGuestStatus, and
	SecHostRemoveGuest, and report hosting status to callers directly. This mode
	is incompatible with dynamic host mode as established by a call to SecHostSetHostingPort.
	
	@param host Pass kSecNoGuest to create a guest of the process itself.
	To create a guest of another guest (extending the hosting chain), pass the SecGuestRef
	of the guest to act as the new guest's host. If host has a dedicated guest,
	it will be deemed to be be the actual host, recursively.
	@param status The Code Signing status word for the new guest. These are combinations
	of the kSecCodeStatus* flags in <Security/CSCommon.h>. Note that the proxy will enforce
	the rules for the stickiness of these bits. In particular, if you don't pass the
	kSecCodeStatusValid bit during creation, your new guest will be born invalid and will
	never have a valid identity.
	@param path The canonical path to the guest's code on disk. This is the path you would
	pass to SecStaticCodeCreateWithPath to make a static code object reference. You must
	use an absolute path.
	@param attributes An optional CFDictionaryRef containing attributes that can be used
	to locate this particular guest among all of the caller's guests. The "canonical"
	attribute is automatically added for the value of guestRef. If you pass NULL,
	no other attributes are established for the guest.
	While any key can be used in the attributes dictionary, the kSecGuestAttribute* constants
	(in SecCode.h) are conventionally used here.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior, or
	a combination of the flags defined below for special features.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
	@param newGuest Upon successful creation of the new guest, the new SecGuestRef
	that should be used to identify the new guest from here on.
	
	@constant kSecCSDedicatedHost Declares dedicated hosting for the given host.
	In dedicated hosting, the host has exactly one guest (the one this call is
	introducing), and the host will spend all of its time from here on running
	that guest (or on its behalf). This declaration is irreversable for the lifetime
	of the host. Note that this is a declaration about the given host, and is not
	binding upon other hosts on either side of the hosting chain, though they in turn
	may declare dedicated hosting if desired.
	It is invalid to declare dedicated hosting if other guests have already been
	introduced for this host, and it is invalid to introduce additional guests
	for this host after this call.
	@constant kSecCSGenerateGuestHash Ask the proxy to generate the binary identifier
	(hash of CodeDirectory) from the copy on disk at the path given. This is not optimal
	since an attacker with write access may be able to substitute a different copy just
	in time, but it is convenient. For optimal security, the host should calculate the
	hash from the loaded in-memory signature of its guest and pass the result as an
	attribute with key kSecGuestAttributeHash.
*/
CF_ENUM(uint32_t) {
	kSecCSDedicatedHost = 1 << 0,
	kSecCSGenerateGuestHash = 1 << 1,
};

OSStatus SecHostCreateGuest(SecGuestRef host,
	uint32_t status, CFURLRef path, CFDictionaryRef __nullable attributes,
	SecCSFlags flags, SecGuestRef * __nonnull newGuest);


/*!
	@function SecHostRemoveGuest
	Announce that the guest with the given guestRef has permanently disappeared.
	It removes all memory of the guest from the hosting system. You cannot remove
	a dedicated guest.

	@param host The SecGuestRef that was used to create guest. You cannot specify
	a proximate host (host of a host) here. However, the substitution for dedicated
	guests described for SecHostCreateGuest also takes place here.
	@param guest The handle for a Guest previously created with SecHostCreateGuest
	that has not previously been destroyed. This guest is to be destroyed now.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecHostRemoveGuest(SecGuestRef host, SecGuestRef guest, SecCSFlags flags);


/*!
	@function SecHostSelectGuest
	Tell the Code Signing host subsystem that the calling thread will now act
	on behalf of the given Guest. This must be a valid Guest previously created
	with SecHostCreateGuest.
	
	@param guestRef The handle for a Guest previously created with SecHostCreateGuest
	on whose behalf this thread will act from now on. This setting will be remembered
	until it is changed (or the thread terminates).
	To indicate that the thread will act on behalf of the Host itself (rather than
	any Guest), pass kSecNoGuest.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecHostSelectGuest(SecGuestRef guestRef, SecCSFlags flags);


/*!
	@function SecHostSelectedGuest
	Retrieve the handle for the Guest currently selected for the calling thread.
	
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@param guestRef Will be assigned the SecGuestRef currently in effect for
	the calling thread. If no Guest is active on this thread (i.e. the thread
	is acting for the Host), the return value is kSecNoGuest.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
*/
OSStatus SecHostSelectedGuest(SecCSFlags flags, SecGuestRef * __nonnull guestRef);


/*!
	@function SecHostSetGuestStatus
	Updates the status of a particular guest.
	
	@param guestRef The handle for a Guest previously created with SecHostCreateGuest
	on whose behalf this thread will act from now on. This setting will be remembered
	until it is changed (or the thread terminates).
	@param status The new Code Signing status word for the guest. The proxy enforces
	the restrictions on changes to guest status; in particular, the kSecCodeStatusValid bit can only
	be cleared, and the kSecCodeStatusHard and kSecCodeStatusKill flags can only be set. Pass the previous
	guest status to indicate that no change is desired.
	@param attributes An optional dictionary containing attributes to be used to distinguish
	this guest from all guests of the caller. If given, it completely replaces the attributes
	specified earlier. If NULL, previously established attributes are retained.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
 */
OSStatus SecHostSetGuestStatus(SecGuestRef guestRef,
	uint32_t status, CFDictionaryRef __nullable attributes,
	SecCSFlags flags);


/*!
	@function SecHostSetHostingPort
	Tells the Code Signing Hosting subsystem that the calling code will directly respond
	to hosting inquiries over the given port.
	
	This API should be the first hosting API call made. With it, the calling code takes
	direct responsibility for answering questions about its guests using the hosting IPC
	services. The SecHostCreateGuest, SecHostDestroyGuest and SecHostSetGuestStatus calls
	are not valid after this. The SecHostSelectGuest and SecHostSelectedGuest calls will
	still work, and will use whatever SecGuestRefs the caller has assigned in its internal
	data structures.
	
	This call cannot be undone; once it is made, record-and-forward facilities are
	disabled for the lifetime of the calling code.
	
	@param hostingPort A Mach message port with send rights. This port will be recorded
	and handed to parties interested in querying the host about its children.
	@param flags Optional flags. Pass kSecCSDefaultFlags for standard behavior.
	@result Upon success, errSecSuccess. Upon error, an OSStatus value documented in
	CSCommon.h or certain other Security framework headers.
 */
OSStatus SecHostSetHostingPort(mach_port_t hostingPort, SecCSFlags flags);

CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif //_H_SECCODEHOST
