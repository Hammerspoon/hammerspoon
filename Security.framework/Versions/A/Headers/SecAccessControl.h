/*
 * Copyright (c) 2014 Apple Inc. All Rights Reserved.
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
 @header SecAccessControl
 SecAccessControl defines access rights for items.
 */

#ifndef _SECURITY_SECACCESSCONTROL_H_
#define _SECURITY_SECACCESSCONTROL_H_

#include <Security/SecBase.h>
#include <CoreFoundation/CFError.h>
#include <sys/cdefs.h>

__BEGIN_DECLS

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
 @function SecAccessControlGetTypeID
 @abstract Returns the type identifier of SecAccessControl instances.
 @result The CFTypeID of SecAccessControl instances.
 */
CFTypeID SecAccessControlGetTypeID(void)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);

typedef CF_OPTIONS(CFOptionFlags, SecAccessControlCreateFlags) {
    kSecAccessControlUserPresence           = 1 << 0,                                 // User presence policy using Touch ID or Passcode. Touch ID does not have to be available or enrolled. Item is still accessible by Touch ID even if fingers are added or removed.
    kSecAccessControlTouchIDAny             CF_ENUM_AVAILABLE(10_12, 9_0) = 1u << 1,   // Constraint: Touch ID (any finger). Touch ID must be available and at least one finger must be enrolled. Item is still accessible by Touch ID even if fingers are added or removed.
    kSecAccessControlTouchIDCurrentSet      CF_ENUM_AVAILABLE(10_12, 9_0) = 1u << 3,   // Constraint: Touch ID from the set of currently enrolled fingers. Touch ID must be available and at least one finger must be enrolled. When fingers are added or removed, the item is invalidated.
    kSecAccessControlDevicePasscode         CF_ENUM_AVAILABLE(10_11, 9_0) = 1u << 4,   // Constraint: Device passcode
    kSecAccessControlOr                     CF_ENUM_AVAILABLE(10_12, 9_0) = 1u << 14,  // Constraint logic operation: when using more than one constraint, at least one of them must be satisfied.
    kSecAccessControlAnd                    CF_ENUM_AVAILABLE(10_12, 9_0) = 1u << 15,  // Constraint logic operation: when using more than one constraint, all must be satisfied.
    kSecAccessControlPrivateKeyUsage        CF_ENUM_AVAILABLE(10_12, 9_0) = 1u << 30,  // Create access control for private key operations (i.e. sign operation)
    kSecAccessControlApplicationPassword    CF_ENUM_AVAILABLE(10_12, 9_0) = 1u << 31,  // Security: Application provided password for data encryption key generation. This is not a constraint but additional item encryption mechanism.
} __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);

/*!
 @function SecAccessControlCreateWithFlags
 @abstract Creates new access control object based on protection type and additional flags.
 @discussion Created access control object should be used as a value for kSecAttrAccessControl attribute in SecItemAdd,
 SecItemUpdate or SecKeyGeneratePair functions.  Accessing keychain items or performing operations on keys which are
 protected by access control objects can block the execution because of UI which can appear to satisfy the access control
 conditions, therefore it is recommended to either move those potentially blocking operations out of the main
 application thread or use combination of kSecUseAuthenticationContext and kSecUseAuthenticationUI attributes to control
 where the UI interaction can appear.
 @param allocator Allocator to be used by this instance.
 @param protection Protection class to be used for the item. One of kSecAttrAccessible constants.
 @param flags If no flags are set then all operations are allowed.
 @param error Additional error information filled in case of failure.
 @result Newly created access control object.
 */
__nullable
SecAccessControlRef SecAccessControlCreateWithFlags(CFAllocatorRef __nullable allocator, CFTypeRef protection,
                                                    SecAccessControlCreateFlags flags, CFErrorRef *error)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

__END_DECLS

#endif // _SECURITY_SECACCESSCONTROL_H_
