/*
 * Copyright (c) 2000-2004,2007,2011-2012 Apple Inc. All Rights Reserved.
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
 *  Authorization.h -- APIs for implementing access control in applications
 *  and daemons.
 */

#ifndef _SECURITY_AUTHORIZATION_H_
#define _SECURITY_AUTHORIZATION_H_

#include <TargetConditionals.h>
#include <MacTypes.h>
#include <Availability.h>
#include <CoreFoundation/CFAvailability.h>
#include <CoreFoundation/CFBase.h>

#include <stdio.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@header Authorization
	Version 1.0 10/16/2000

	The Authorization API contains all the APIs that a application or tool that need pre-authorization or need an authorization desision made.
	
	A typical use cases are a preference panel that would start off calling AuthorizationCreate() (without UI) to get an authorization object.  Then call AuthorizationCopyRights() to figure out what is currently allowed.
	
	If any of the operations that the preference panel wishes to perform are currently not allowed the lock icon in the window would show up in the locked state.  Otherwise it would show up unlocked.
	
	When the user locks the lock AuthorizationFree() is called with the kAuthorizationFlagDestroyRights to destroy any authorization rights that have been aquired.
	
	When the user unlocks the lock AuthorizationCreate() is called with the kAuthorizationFlagInteractionAllowed and kAuthorizationFlagExtendRights flags to obtain all required rights.  The old authorization object can be freed by calling AuthorizationFree() with no flags.

*/



/*!
	@defined kAuthorizationEmptyEnvironment
	Parameter to specify to AuthorizationCreate when no environment is being provided.
*/
#define kAuthorizationEmptyEnvironment	NULL


/*!
	@enum AuthorizationStatus
	Error codes returned by Authorization API.
*/

/*
    Note: the comments that appear after these errors are used to create SecErrorMessages.strings.
    The comments must not be multi-line, and should be in a form meaningful to an end user. If
    a different or additional comment is needed, it can be put in the header doc format, or on a
    line that does not start with errZZZ.

    errAuthorizationSuccess can't include a string as it's also errSecSuccess in libsecurity_keychain/lib/SecBase.h
*/

CF_ENUM(OSStatus) {
	errAuthorizationSuccess                 = 0,
	errAuthorizationInvalidSet              = -60001, /* The authorization rights are invalid. */
	errAuthorizationInvalidRef              = -60002, /* The authorization reference is invalid. */
	errAuthorizationInvalidTag              = -60003, /* The authorization tag is invalid. */
	errAuthorizationInvalidPointer          = -60004, /* The returned authorization is invalid. */
	errAuthorizationDenied                  = -60005, /* The authorization was denied. */
	errAuthorizationCanceled                = -60006, /* The authorization was cancelled by the user. */
	errAuthorizationInteractionNotAllowed   = -60007, /* The authorization was denied since no user interaction was possible. */
	errAuthorizationInternal                = -60008, /* Unable to obtain authorization for this operation. */
	errAuthorizationExternalizeNotAllowed	= -60009, /* The authorization is not allowed to be converted to an external format. */
	errAuthorizationInternalizeNotAllowed	= -60010, /* The authorization is not allowed to be created from an external format. */
	errAuthorizationInvalidFlags            = -60011, /* The provided option flag(s) are invalid for this authorization operation. */
	errAuthorizationToolExecuteFailure      = -60031, /* The specified program could not be executed. */
	errAuthorizationToolEnvironmentError    = -60032, /* An invalid status was returned during execution of a privileged tool. */
	errAuthorizationBadAddress              = -60033, /* The requested socket address is invalid (must be 0-1023 inclusive). */
};


/*!
	@typedef AuthorizationFlags
	Optional flags passed in to several Authorization APIs.
	See the description of AuthorizationCreate, AuthorizationCopyRights and AuthorizationFree for a description of how they affect those calls.
*/
typedef CF_OPTIONS(UInt32, AuthorizationFlags) {
	kAuthorizationFlagDefaults              =  0,
	kAuthorizationFlagInteractionAllowed	= (1 << 0),
	kAuthorizationFlagExtendRights			= (1 << 1),
	kAuthorizationFlagPartialRights			= (1 << 2),
	kAuthorizationFlagDestroyRights			= (1 << 3),
	kAuthorizationFlagPreAuthorize			= (1 << 4),
	
	// private bits (do not use)
	kAuthorizationFlagNoData                = (1 << 20)
};


/*!
	@enum AuthorizationRightFlags
	Flags returned in the flags field of ItemSet Items when calling AuthorizationCopyRights().
*/
enum {
	kAuthorizationFlagCanNotPreAuthorize	= (1 << 0)
};


/*!
	@typedef AuthorizationRef
	Opaque reference to an authorization object.
*/
typedef const struct AuthorizationOpaqueRef			*AuthorizationRef;


/*!
	@typedef AuthorizationString
	A zero terminated string in UTF-8 encoding.
*/
typedef const char *AuthorizationString;


/*!
	@struct AuthorizationItem
	Each AuthorizationItem describes a single string-named item with optional
	parameter value. The value must be contiguous memory of valueLength bytes;
	internal structure is defined separately for each name.

	@field name name of the item, as an AuthorizationString. Mandatory.
	@field valueLength Number of bytes in parameter value. Must be 0 if no parameter value.
	@field value Pointer to the optional parameter value associated with name.
	Must be NULL if no parameter value.
	@field flags Reserved field. Must be set to 0 on creation. Do not modify after that.
*/
typedef struct {
	AuthorizationString name;
	size_t valueLength;
	void * __nullable value;
	UInt32 flags;
} AuthorizationItem;


/*!
	@struct AuthorizationItemSet
	An AuthorizationItemSet structure represents a set of zero or more AuthorizationItems.  Since it is a set it should not contain any identical AuthorizationItems.

	@field count Number of items identified by items.
	@field items Pointer to an array of items.
*/
typedef struct {
	UInt32 count;
	AuthorizationItem * __nullable items;
} AuthorizationItemSet;



/*!
	@struct AuthorizationExternalForm
	An AuthorizationExternalForm structure can hold the externalized form of
	an AuthorizationRef. As such, it can be transmitted across IPC channels
	to other processes, which can re-internalize it to recover a valid AuthorizationRef
	handle.
	The data contained in an AuthorizationExternalForm should be considered opaque.

	SECURITY NOTE: Applications should take care to not disclose the AuthorizationExternalForm to
	potential attackers since it would authorize rights to them.
*/
static const size_t kAuthorizationExternalFormLength = 32;

typedef struct {
	char bytes[kAuthorizationExternalFormLength];
} AuthorizationExternalForm;



/*!
	@typedef AuthorizationRights
	An AuthorizationItemSet representing a set of rights each with an associated argument (value).
	Each argument value is as defined for the specific right they belong to.  Argument values may not contain pointers as the should be copyable to different address spaces.
*/
typedef AuthorizationItemSet AuthorizationRights;


/*!
	@typedef AuthorizationEnvironment
	An AuthorizationItemSet representing environmental information of potential use
	to authorization decisions.
*/
typedef AuthorizationItemSet AuthorizationEnvironment;


/*!
    @function AuthorizationCreate
    Create a new autorization object which can be used in other authorization calls.  When the authorization is no longer needed AuthorizationFree should be called.

	When the kAuthorizationFlagInteractionAllowed flag is set, user interaction will happen when required.  Failing to set this flag will result in this call failing with a errAuthorizationInteractionNotAllowed status when interaction is required.

	Setting the kAuthorizationFlagExtendRights flag will extend the currently available rights. If this flag is set the returned AuthorizationRef will grant all the rights requested when errAuthorizationSuccess is returned. If this flag is not set the operation will almost certainly succeed, but no attempt will be made to make the requested rights availible.
		Call AuthorizationCopyRights to figure out which of the requested rights are granted by the returned AuthorizationRef.

	Setting the kAuthorizationFlagPartialRights flag will cause this call to succeed if only some of the requested rights are being granted by the returned AuthorizationRef. Unless this flag is set this API will fail if not all the requested rights could be obtained.

	Setting the kAuthorizationFlagDestroyRights flag will prevent any rights obtained during this call from being preserved after returning from this API (This is most useful when the authorization parameter is NULL and the caller doesn't want to affect the session state in any way).

	Setting the kAuthorizationFlagPreAuthorize flag will pre authorize the requested rights so that at a later time -- by calling AuthorizationMakeExternalForm() follow by AuthorizationCreateFromExternalForm() -- the obtained rights can be used in a different process.  Rights that can't be preauthorized will be treated as if they were authorized for the sake of returning an error (in other words if all rights are either authorized or could not be preauthorized this call will still succeed).
		The rights which could not be preauthorized are not currently authorized and may fail to authorize when a later call to AuthorizationCopyRights() is made, unless the kAuthorizationFlagExtendRights and kAuthorizationFlagInteractionAllowed flags are set.  Even then they might still fail if the user does not supply the correct credentials.
		The reason for passing in this flag is to provide correct audit trail information and to avoid unnecessary user interaction.

    @param rights (input/optional) An AuthorizationItemSet containing rights for which authorization is being requested.  If none are specified the resulting AuthorizationRef will authorize nothing at all.
    @param environment (input/optional) An AuthorizationItemSet containing environment state used when making the autorization decision.  See the AuthorizationEnvironment type for details.
    @param flags (input) options specified by the AuthorizationFlags enum.  set all unused bits to zero to allow for future expansion.
    @param authorization (output optional) A pointer to an AuthorizationRef to be returned.  When the returned AuthorizationRef is no longer needed AuthorizationFree should be called to prevent anyone from using the aquired rights.  If NULL is specified no new rights are returned, but the system will attempt to authorize all the requested rights and return the appropriate status.

    @result errAuthorizationSuccess 0 authorization or all requested rights succeeded.

	errAuthorizationDenied -60005 The authorization for one or more of the requested rights was denied.

	errAuthorizationCanceled -60006 The authorization was cancelled by the user.

	errAuthorizationInteractionNotAllowed -60007 The authorization was denied since no interaction with the user was allowed.
*/
OSStatus AuthorizationCreate(const AuthorizationRights * __nullable rights,
	const AuthorizationEnvironment * __nullable environment,
	AuthorizationFlags flags,
	AuthorizationRef __nullable * __nullable authorization);


/*!
    @function AuthorizationFree
    Destroy an AutorizationRef object. If the kAuthorizationFlagDestroyRights flag is passed,
	any rights associated with the authorization are lost. Otherwise, only local resources
	are released, and the rights may still be available to other clients.

	Setting the kAuthorizationFlagDestroyRights flag will prevent any rights that were obtained by the specified authorization object to be preserved after returning from this API.  This effectivaly locks down all potentially shared authorizations.

    @param authorization (input) The authorization object on which this operation is performed.
	
	@param flags (input) Bit mask of option flags to this call.

    @result errAuthorizationSuccess 0 No error.

    errAuthorizationInvalidRef -60002 The authorization parameter is invalid.
*/
OSStatus AuthorizationFree(AuthorizationRef authorization, AuthorizationFlags flags);


/*!
	@function AuthorizationCopyRights
    Given a set of rights, return the subset that is currently authorized
    by the AuthorizationRef given.

	When the kAuthorizationFlagInteractionAllowed flag is set, user interaction will happen when required.  Failing to set this flag will result in this call failing with a errAuthorizationInteractionNotAllowed status when interaction is required.

	Setting the kAuthorizationFlagExtendRights flag will extend the currently available rights.

	Setting the kAuthorizationFlagPartialRights flag will cause this call to succeed if only some of the requested rights are being granted by the returned AuthorizationRef.  Unless this flag is set this API will fail if not all the requested rights could be obtained.

	Setting the kAuthorizationFlagDestroyRights flag will prevent any additional rights obtained during this call from being preserved after returning from this API.

	Setting the kAuthorizationFlagPreAuthorize flag will pre authorize the requested rights so that at a later time -- by calling AuthorizationMakeExternalForm() follow by AuthorizationCreateFromExternalForm() -- the obtained rights can be used in a different process.  Rights that can't be preauthorized will be treated as if they were authorized for the sake of returning an error (in other words if all rights are either authorized or could not be preauthorized this call will still succeed), and they will be returned in authorizedRights with their kAuthorizationFlagCanNotPreAuthorize bit in the flags field set to 1.
		The rights which could not be preauthorized are not currently authorized and may fail to authorize when a later call to AuthorizationCopyRights() is made, unless the kAuthorizationFlagExtendRights and kAuthorizationFlagInteractionAllowed flags are set.  Even then they might still fail if the user does not supply the correct credentials.
		The reason for passing in this flag is to provide correct audit trail information and to avoid unnecessary user interaction.

	Setting the kAuthorizationFlagPreAuthorize flag will pre authorize the requested rights so that at a later time -- by calling AuthorizationMakeExternalForm() follow by AuthorizationCreateFromExternalForm() -- the obtained rights can be used in a different process.  When this flags is specified rights that can't be preauthorized will be returned as if they were authorized with their kAuthorizationFlagCanNotPreAuthorize bit in the flags field set to 1.  These rights are not currently authorized and may fail to authorize later unless kAuthorizationFlagExtendRights and kAuthorizationFlagInteractionAllowed flags are set when the actual authorization is done.  And even then they might still fail if the user does not supply the correct credentials.

    @param authorization (input) The authorization object on which this operation is performed.
    @param rights (input) A rights set (see AuthorizationCreate).
    @param environment (input/optional) An AuthorizationItemSet containing environment state used when making the autorization decision.  See the AuthorizationEnvironment type for details.
    @param flags (input) options specified by the AuthorizationFlags enum.  set all unused bits to zero to allow for future expansion.
    @param authorizedRights (output/optional) A pointer to a newly allocated AuthorizationInfoSet in which the authorized subset of rights are returned (authorizedRights should be deallocated by calling AuthorizationFreeItemSet() when it is no longer needed).  If NULL the only information returned is the status.  Note that if the kAuthorizationFlagPreAuthorize flag was specified rights that could not be preauthorized are returned in authorizedRights, but their flags contains the kAuthorizationFlagCanNotPreAuthorize bit.

    @result errAuthorizationSuccess 0 No error.

	errAuthorizationInvalidRef -60002 The authorization parameter is invalid.

    errAuthorizationInvalidSet -60001 The rights parameter is invalid.

    errAuthorizationInvalidPointer -60004 The authorizedRights parameter is invalid.
*/
OSStatus AuthorizationCopyRights(AuthorizationRef authorization, 
	const AuthorizationRights *rights,
	const AuthorizationEnvironment * __nullable environment,
	AuthorizationFlags flags,
	AuthorizationRights * __nullable * __nullable authorizedRights);

	
#ifdef __BLOCKS__
	
/*!
	@typedef AuthorizationAsyncCallback
	Callback block passed to AuthorizationCopyRightsAsync.

	@param err (output) The result of the AuthorizationCopyRights call.
	@param blockAuthorizedRights (output) The authorizedRights from the AuthorizationCopyRights call to be deallocated by calling AuthorizationFreeItemSet() when it is no longer needed.
*/
typedef void (^AuthorizationAsyncCallback)(OSStatus err, AuthorizationRights * __nullable blockAuthorizedRights);

/*!
	@function AuthorizationCopyRightsAsync
	An asynchronous version of AuthorizationCopyRights.

	@param callbackBlock (input) The callback block to be called upon completion.
*/
void AuthorizationCopyRightsAsync(AuthorizationRef authorization,
	const AuthorizationRights *rights,
	const AuthorizationEnvironment * __nullable environment,
	AuthorizationFlags flags,
	AuthorizationAsyncCallback callbackBlock);

	
#endif /* __BLOCKS__ */	
	
	
/*!
	@function AuthorizationCopyInfo
	Returns sideband information (e.g. access credentials) obtained from a call to AuthorizationCreate.  The format of this data depends of the tag specified.
	
    @param authorization (input) The authorization object on which this operation is performed.
    @param tag (input/optional) An optional string tag specifing which sideband information should be returned.  When NULL is specified all available information is returned.
    @param info (output) A pointer to a newly allocated AuthorizationInfoSet in which the requested sideband infomation is returned (info should be deallocated by calling AuthorizationFreeItemSet() when it is no longer needed).

    @result errAuthorizationSuccess 0 No error.

    errAuthorizationInvalidRef -60002 The authorization parameter is invalid.

    errAuthorizationInvalidTag -60003 The tag parameter is invalid.

    errAuthorizationInvalidPointer -60004 The info parameter is invalid.
*/
OSStatus AuthorizationCopyInfo(AuthorizationRef authorization, 
	AuthorizationString __nullable tag,
	AuthorizationItemSet * __nullable * __nonnull info);


/*!
	@function AuthorizationMakeExternalForm
	Turn an Authorization into an external "byte blob" form so it can be
	transmitted to another process.
	Note that *storing* the external form somewhere will probably not do what
	you want, since authorizations are bounded by sessions, processes, and possibly
	time limits. This is for online transmission of authorizations.
	
	@param authorization The (valid) authorization reference to externalize
	@param extForm Pointer to an AuthorizationExternalForm variable to fill.
	
        @result errAuthorizationSuccess 0 No error.

        errAuthorizationExternalizeNotAllowed -60009 Externalizing this authorization is not allowed.

        errAuthorizationInvalidRef -60002 The authorization parameter is invalid.


*/
OSStatus AuthorizationMakeExternalForm(AuthorizationRef authorization,
	AuthorizationExternalForm * __nonnull extForm);


/*!
	@function AuthorizationCreateFromExternalForm
	Internalize the external "byte blob" form of an authorization reference.
	
	@param extForm Pointer to an AuthorizationExternalForm value.
	@param authorization Will be filled with a valid AuthorizationRef on success.
	
	@result errAuthorizationInternalizeNotAllowed -60010 Internalizing this authorization is not allowed.
*/
OSStatus AuthorizationCreateFromExternalForm(const AuthorizationExternalForm *extForm,
	AuthorizationRef __nullable * __nonnull authorization);


/*!
	@function AuthorizationFreeItemSet
	Release the memory allocated for an AuthorizationItemSet that was allocated
	by an API call.
	
    @param set The AuthorizationItemSet to deallocate.

    @result errAuthorizationSuccess 0 No error.

    errAuthorizationInvalidSet -60001 The set parameter is invalid.
*/
OSStatus AuthorizationFreeItemSet(AuthorizationItemSet *set);


/*!
	@function AuthorizationExecuteWithPrivileges
	Run an executable tool with enhanced privileges after passing
	suitable authorization procedures.
	
	@param authorization An authorization reference that is used to authorize
	access to the enhanced privileges. It is also passed to the tool for
	further access control.
	@param pathToTool Full pathname to the tool that should be executed
	with enhanced privileges.
	@param options Option bits (reserved). Must be zero.
	@param arguments An argv-style vector of strings to be passed to the tool.
	@param communicationsPipe Assigned a UNIX stdio FILE pointer for
	a bidirectional pipe to communicate with the tool. The tool will have
	this pipe as its standard I/O channels (stdin/stdout). If NULL, do not
	establish a communications pipe.

 	@discussion This function has been deprecated and should no longer be used.
 	Use a launchd-launched helper tool and/or the Service Mangement framework
 	for this functionality.
 */
OSStatus AuthorizationExecuteWithPrivileges(AuthorizationRef authorization,
	const char *pathToTool,
	AuthorizationFlags options,
	char * __nonnull const * __nonnull arguments,
	FILE * __nullable * __nullable communicationsPipe) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_1,__MAC_10_7,__IPHONE_NA,__IPHONE_NA);


/*!
	@function AuthorizationCopyPrivilegedReference
	From within a tool launched via the AuthorizationExecuteWithPrivileges function
	ONLY, retrieve the AuthorizationRef originally passed to that function.
	While AuthorizationExecuteWithPrivileges already verified the authorization to
	launch your tool, the tool may want to avail itself of any additional pre-authorizations
	the caller may have obtained through that reference.
 
	@discussion This function has been deprecated and should no longer be used.
	Use a launchd-launched helper tool and/or the Service Mangement framework
	for this functionality.
 */
OSStatus AuthorizationCopyPrivilegedReference(AuthorizationRef __nullable * __nonnull authorization,
	AuthorizationFlags flags) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_1,__MAC_10_7,__IPHONE_NA,__IPHONE_NA);

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_AUTHORIZATION_H_ */
