/*
 * Copyright (c) 2002-2004,2011,2014 Apple Inc. All Rights Reserved.
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
	@header SecPolicySearch
	The functions provided in SecPolicySearch implement a query for SecPolicy objects.
*/

#ifndef _SECURITY_SECPOLICYSEARCH_H_
#define _SECURITY_SECPOLICYSEARCH_H_

#include <Security/SecBase.h>
#include <Security/cssmtype.h>


#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@typedef SecPolicySearchRef
	@abstract A reference to an opaque policy search structure.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaquePolicySearchRef *SecPolicySearchRef;

/*!
	@function SecPolicySearchGetTypeID
	@abstract Returns the type identifier of SecPolicySearch instances.
	@result The CFTypeID of SecPolicySearch instances.
	@discussion This API is deprecated in 10.7. The SecPolicySearchRef type is no longer used.
*/
CFTypeID SecPolicySearchGetTypeID(void)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
	@function SecPolicySearchCreate
	@abstract Creates a search reference for finding a policy by specifying its object identifier.
	@param certType The type of certificates a policy uses.
    @param policyOID A pointer to a BER-encoded policy object identifier that uniquely specifies the policy.
	@param value Unused.  Pass NULL for this value.  Use SecPolicySetValue to set per policy data.
	@param searchRef On return, a pointer to a policy search reference. The policy search reference is used for subsequent calls to the SecCopyNextPolicy function to obtain the remaining trust policies. You are responsible for releasing the search reference by calling the CFRelease function when finished with it.
    @result A result code.  See "Security Error Codes" (SecBase.h).
	@discussion This function is deprecated in 10.7. To create a SecPolicyRef, use one of the SecPolicyCreate functions in SecPolicy.h.
*/
OSStatus SecPolicySearchCreate(CSSM_CERT_TYPE certType, const CSSM_OID *policyOID, const CSSM_DATA * __nullable value, SecPolicySearchRef * __nonnull CF_RETURNS_RETAINED searchRef)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
	@function SecPolicySearchCopyNext
	@abstract Finds the next policy matching the given search criteria
	@param searchRef A reference to the current policy search criteria.	You create the policy search  reference by a calling the SecPolicySearchCreate function. You are responsible for releasing the policy by calling the CFRelease function when finished with it.
	@param policyRef On return, a pointer to a policy reference.
	@result A result code.  When there are no more policies that match the parameters specified to SecPolicySearchCreate, errSecPolicyNotFound is returned. See "Security Error Codes" (SecBase.h).
	@discussion This function is deprecated in 10.7. To create a SecPolicyRef, use one of the SecPolicyCreate functions in SecPolicy.h.
*/
OSStatus SecPolicySearchCopyNext(SecPolicySearchRef searchRef, SecPolicyRef * __nonnull CF_RETURNS_RETAINED policyRef)
		DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECPOLICY_H_ */
