/*
 * Copyright (c) 2003,2011,2014 Apple Inc. All Rights Reserved.
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

/*
 *  AuthorizationDB.h -- APIs for managing the authorization policy database
 *  and daemons.
 */

#ifndef _SECURITY_AUTHORIZATIONDB_H_
#define _SECURITY_AUTHORIZATIONDB_H_

#include <Security/Authorization.h>
#include <CoreFoundation/CoreFoundation.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@header AuthorizationDB
	Version 1.0

	This API allows for any programs to get, modify, delete and add new right definitions to the policy database.  Meta-rights specify whether and what authorization is required to make these modifications.
	
	AuthorizationRightSet(authRef, "com.ifoo.ifax.send", CFSTR(kRuleIsAdmin), CFSTR("You must authenticate to send a fax."), NULL, NULL)

	add a rule for letting admins send faxes using a canned rule, delegating to a pre-specified rule that authorizes everyone who is an admin.
	
	AuthorizationRightSet(authRef, "com.ifoo.ifax.send", [[CFSTR(kRightRule), CFSTR(kRuleIsAdmin)], [CFSTR(kRightComment), CFSTR("authorizes sending of 1 fax message")]], CFSTR("Authorize sending of a fax"), NULL, NULL)

	add identical rule, but specify additional attributes this time.

	Keep in mind while specifying a comment to be specific about what you need to authorize for (1 fax), in terms of a general message for user.  The means of proof required for kRuleIsAdmin (enter username/password for example) should not be included here, since it could be configured differently.  Also note that the "authRef" variable used in each of the above examples must be a vaild AuthorizationRef obtained from AuthorizationCreate().

*/

/*!	@define kRightRule
	rule delegation key.  Instead of specifying exact behavior some canned rules
   are shipped that may be switched by configurable security.
*/
#define kAuthorizationRightRule						"rule"

/*! @defined kRuleIsAdmin
	canned rule values for use with rule delegation definitions: require user to be an admin.
*/
#define kAuthorizationRuleIsAdmin					"is-admin"

/*! @defined kRuleAuthenticateAsSessionUser
	canned rule value for use with rule delegation definitions: require user to authenticate as the session owner (logged-in user).
*/
#define kAuthorizationRuleAuthenticateAsSessionUser	"authenticate-session-owner"

/*! @defined kRuleAuthenticateAsAdmin
	Canned rule value for use with rule delegation definitions: require user to authenticate as admin.
*/
#define kAuthorizationRuleAuthenticateAsAdmin		"authenticate-admin"

/*! @defined kAuthorizationRuleClassAllow
	Class that allows anything.
*/
#define kAuthorizationRuleClassAllow			"allow"

/*! @defined kAuthorizationRuleClassDeny
	Class that denies anything. 
*/
#define kAuthorizationRuleClassDeny				"deny"

/*! @defined kAuthorizationComment
    comments for the administrator on what is being customized here;
   as opposed to (localized) descriptions presented to the user.
*/
#define kAuthorizationComment	"comment"



/*!
	@function AuthorizationRightGet 
	
	Retrieves a right definition as a dictionary.  There are no restrictions to keep anyone from retrieving these definitions.  

	@param rightName (input) the rightname (ASCII).  Wildcard rightname definitions are okay.
	@param rightDefinition (output/optional) the dictionary with all keys defining the right.  See documented keys.  Passing in NULL will just check if there is a definition.  The caller is responsible for releasing the returned dictionary.

	@result errAuthorizationSuccess 0 No error.

	errAuthorizationDenied -60005 No definition found.

*/
OSStatus AuthorizationRightGet(const char *rightName,
	CFDictionaryRef * __nullable CF_RETURNS_RETAINED rightDefinition);

/*!
	@function AuthorizationRightSet
	
	Create or update a right entry.  Only normal rights can be registered (wildcard rights are denied); wildcard rights are considered to be put in by an administrator putting together a site configuration.

	@param authRef (input) authRef to authorize modifications.
	@param rightName (input) the rightname (ASCII).  Wildcard rightnames are not okay.
	@param rightDefinition (input) a CFString of the name of a rule to use (delegate) or CFDictionary containing keys defining one.
	@param descriptionKey (input/optional) a CFString to use as a key for looking up localized descriptions.  If no localization is found this will be the description itself.
	@param bundle (input/optional) a bundle to get localizations from if not the main bundle.
	@param localeTableName (input/optional) stringtable name to get localizations from.
	
	@result errAuthorizationSuccess 0 added right definition successfully.

	errAuthorizationDenied -60005 Unable to create or update right definition.

	errAuthorizationCanceled -60006 Authorization was canceled by user.

	errAuthorizationInteractionNotAllowed -60007 Interaction was required but not possible.

*/
OSStatus AuthorizationRightSet(AuthorizationRef authRef,
	const char *rightName,
	CFTypeRef rightDefinition,
	CFStringRef __nullable descriptionKey,
	CFBundleRef __nullable bundle,
	CFStringRef __nullable localeTableName);



/*!
	@function AuthorizationRightRemove

	Request to remove a right from the policy database.

	@param authRef (input) authRef, to be used to authorize this action.
	@param rightName (input) the rightname (ASCII).  Wildcard rightnames are not okay.
	
*/
OSStatus AuthorizationRightRemove(AuthorizationRef authRef,
	const char *rightName);

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_AUTHORIZATIONDB_H_ */

