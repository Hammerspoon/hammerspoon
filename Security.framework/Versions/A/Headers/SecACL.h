/*
 * Copyright (c) 2002-2011 Apple Inc. All Rights Reserved.
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
 @header SecACL
 The functions provided in SecACL are for managing entries in the access control list.  
 */

#ifndef _SECURITY_SECACL_H_
#define _SECURITY_SECACL_H_

#include <Security/SecBase.h>
#include <Security/cssmtype.h>
#include <Security/cssmapple.h>
#include <Security/SecAccess.h>
#include <CoreFoundation/CoreFoundation.h>


#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

	typedef CF_OPTIONS(uint16, SecKeychainPromptSelector)
	{
		kSecKeychainPromptRequirePassphase = 0x0001, /* require re-entering of passphrase */
		/* the following bits are ignored by 10.4 and earlier */
		kSecKeychainPromptUnsigned = 0x0010,			/* prompt for unsigned clients */
		kSecKeychainPromptUnsignedAct = 0x0020,		/* UNSIGNED bit overrides system default */
		kSecKeychainPromptInvalid = 0x0040,			/* prompt for invalid signed clients */
		kSecKeychainPromptInvalidAct = 0x0080,
	};
	
	
	/*!
	 @function SecACLGetTypeID
	 @abstract Returns the type identifier of SecACL instances.
	 @result The CFTypeID of SecACL instances.
	 */
	CFTypeID SecACLGetTypeID(void)
	__OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_NA);
	
	/*!
	 @function SecACLCreateFromSimpleContents
	 @abstract Creates a new access control list entry from the application list, description, and prompt selector provided and adds it to an item's access.
	 @param access An access reference.
	 @param applicationList An array of SecTrustedApplication instances that will be allowed access without prompting. 
	 @param description The human readable name that will be used to refer to this item when the user is prompted.
	 @param promptSelector A pointer to a CSSM prompt selector.
	 @param newAcl A pointer to an access control list entry.  On return, this points to the reference of the new access control list entry.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 @discussion This function is deprecated in 10.7 and later;
	 use SecACLCreateWithSimpleContents instead.
	 */
	OSStatus SecACLCreateFromSimpleContents(SecAccessRef access,
											CFArrayRef __nullable applicationList,
											CFStringRef description,
                                            const CSSM_ACL_KEYCHAIN_PROMPT_SELECTOR *promptSelector,
											SecACLRef * __nonnull CF_RETURNS_RETAINED newAcl)
	 DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;
	
	/*!
	 @function SecACLCreateWithSimpleContents
	 @abstract Creates a new access control list entry from the application list, description, and prompt selector provided and adds it to an item's access.
	 @param access An access reference.
	 @param applicationList An array of SecTrustedApplication instances that will be allowed access without prompting. 
	 @param description The human readable name that will be used to refer to this item when the user is prompted.
	 @param promptSelector A SecKeychainPromptSelector selector.
	 @param newAcl A pointer to an access control list entry.  On return, this points to the reference of the new access control list entry.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 */
	OSStatus SecACLCreateWithSimpleContents(SecAccessRef access,
											CFArrayRef __nullable applicationList,
											CFStringRef description, 
											SecKeychainPromptSelector promptSelector,
											SecACLRef * __nonnull CF_RETURNS_RETAINED newAcl)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
	
	/*!
	 @function SecACLRemove
	 @abstract Removes the access control list entry specified.
	 @param aclRef The reference to the access control list entry to remove.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 */
	OSStatus SecACLRemove(SecACLRef aclRef)
	__OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_NA);
	
	/*!
	 @function SecACLCopySimpleContents
	 @abstract Returns the application list, description, and CSSM prompt selector for a given access control list entry.
	 @param acl An access control list entry reference.
	 @param applicationList On return, An array of SecTrustedApplication instances that will be allowed access without prompting, for the given access control list entry.  The caller needs to call CFRelease on this array when it's no longer needed.
	 @param description On return, the human readable name that will be used to refer to this item when the user is prompted, for the given access control list entry. The caller needs to call CFRelease on this string when it's no longer needed.
	 @param promptSelector A pointer to a CSSM prompt selector.  On return, this points to the CSSM prompt selector for the given access control list entry.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 @discussion This function is deprecated in 10.7 and later;
	 use SecACLCopyContents instead.
	 */
	OSStatus SecACLCopySimpleContents(SecACLRef acl,
									  CFArrayRef * __nonnull CF_RETURNS_RETAINED applicationList,
									  CFStringRef * __nonnull CF_RETURNS_RETAINED description,
                                      CSSM_ACL_KEYCHAIN_PROMPT_SELECTOR *promptSelector)
	 DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;
	
	/*!
	 @function SecACLCopyContents
	 @abstract Returns the application list, description, and prompt selector for a given access control list entry.
	 @param acl An access control list entry reference.
	 @param applicationList On return, An array of SecTrustedApplication instances that will be allowed access without prompting, for the given access control list entry.  The caller needs to call CFRelease on this array when it's no longer needed.
	 @param description On return, the human readable name that will be used to refer to this item when the user is prompted, for the given access control list entry. The caller needs to call CFRelease on this string when it's no longer needed.
	 @param promptSelector A pointer to a SecKeychainPromptSelector.  On return, this points to the SecKeychainPromptSelector for the given access control list entry.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 */	
	OSStatus SecACLCopyContents(SecACLRef acl,
								CFArrayRef * __nonnull CF_RETURNS_RETAINED applicationList,
								CFStringRef * __nonnull CF_RETURNS_RETAINED description,
								SecKeychainPromptSelector *promptSelector)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
	/*!
	 @function SecACLSetSimpleContents
	 @abstract Sets the application list, description, and CSSM prompt selector for a given access control list entry.
	 @param acl A reference to the access control list entry to edit.
	 @param applicationList An application list reference. 
	 @param description The human readable name that will be used to refer to this item when the user is prompted.
	 @param promptSelector A pointer to a CSSM prompt selector.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 @discussion This function is deprecated in 10.7 and later;
	 use SecACLSetContents instead.
	 */
	OSStatus SecACLSetSimpleContents(SecACLRef acl,
									 CFArrayRef __nullable applicationList,
									 CFStringRef description,
                                     const CSSM_ACL_KEYCHAIN_PROMPT_SELECTOR *promptSelector)
	 DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;
	
	/*!
	 @function SecACLSetContents
	 @abstract Sets the application list, description, and prompt selector for a given access control list entry.
	 @param acl A reference to the access control list entry to edit.
	 @param applicationList An application list reference. 
	 @param description The human readable name that will be used to refer to this item when the user is prompted.
	 @param promptSelector A SecKeychainPromptSelector selector.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 */
	OSStatus SecACLSetContents(SecACLRef acl,
							   CFArrayRef __nullable applicationList,
							   CFStringRef description, 
							   SecKeychainPromptSelector promptSelector)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
	
	/*!
	 @function SecACLGetAuthorizations
	 @abstract Retrieve the CSSM authorization tags of a given access control list entry.
	 @param acl An access control list entry reference.
	 @param tags On return, this points to the first item in an array of CSSM authorization tags.
	 @param tagCount On return, this points to the number of tags in the CSSM authorization tag array.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 @discussion This function is deprecated in 10.7 and later;
	 use SecACLCopyAuthorizations instead.
	 */
	OSStatus SecACLGetAuthorizations(SecACLRef acl,
									 CSSM_ACL_AUTHORIZATION_TAG *tags, uint32 *tagCount)
	 DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;
	
	/*!
	 @function SecACLCopyAuthorizations
	 @abstract Retrieve the authorization tags of a given access control list entry.
	 @param acl An access control list entry reference.
	 @result On return, a CFArrayRef of the authorizations for this ACL.
	 */
	CFArrayRef SecACLCopyAuthorizations(SecACLRef acl)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);
	
	/*!
	 @function SecACLSetAuthorizations
	 @abstract Sets the CSSM authorization tags of a given access control list entry.
	 @param acl An access control list entry reference.
	 @param tags A pointer to the first item in an array of CSSM authorization tags.
	 @param tagCount The number of tags in the CSSM authorization tag array.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 @discussion This function is deprecated in 10.7 and later;
	 use SecACLUpdateAuthorizations instead.
	 */
	OSStatus SecACLSetAuthorizations(SecACLRef acl,
									 CSSM_ACL_AUTHORIZATION_TAG *tags, uint32 tagCount)
	 DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;
	
	
	/*!
	 @function SecACLUpdateAuthorizations
	 @abstract Sets the authorization tags of a given access control list entry.
	 @param acl An access control list entry reference.
	 @param authorizations A pointer to an array of authorization tags.
	 @result A result code.  See "Security Error Codes" (SecBase.h).
	 */
	OSStatus SecACLUpdateAuthorizations(SecACLRef acl, CFArrayRef authorizations)
	__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECACL_H_ */
