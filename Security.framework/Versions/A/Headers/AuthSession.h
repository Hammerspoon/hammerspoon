/*
 * Copyright (c) 2000-2003,2011,2013-2014 Apple Inc. All Rights Reserved.
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
 *  AuthSession.h
 *  AuthSession - APIs for managing login, authorization, and security Sessions.
 */
#if !defined(__AuthSession__)
#define __AuthSession__ 1

#include <Security/Authorization.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@header AuthSession

	The Session API provides specialized applications access to Session management and inquiry
    functions. This is a specialized API that should not be of interest to most people.
	
	The Security subsystem separates all processes into Security "sessions". Each process is in
	exactly one session, and session membership inherits across fork/exec. Sessions form boundaries
	for security-related state such as authorizations, keychain lock status, and the like.
	Typically, each successful login (whether graphical or through ssh & friends) creates
	a separate session. System daemons (started at system startup) belong to the "root session"
	which has no user nor graphics access.
    
	Sessions are identified with SecuritySessionIds. A session has a set of attributes
	that are set on creation and can be retrieved with SessionGetInfo().
	
	There are similar session concepts in the system, related but not necessarily
	completely congruous. In particular, graphics sessions track security sessions
	(but only for graphic logins).
*/


/*!
	@typedef SecuritySessionId
	These are externally visible identifiers for authorization sessions.
        Different sessions have different identifiers; beyond that, you can't
        tell anything from these values.
    SessionIds can be compared for equality as you'd expect, but you should be careful
        to use attribute bits wherever appropriate.
*/
typedef UInt32 SecuritySessionId;


/*!
    @enum SecuritySessionId
    Here are some special values for SecuritySessionId. You may specify those
        on input to SessionAPI functions. They will never be returned from such
        functions.
    
    Note: -2 is reserved (see 4487137).  
*/
CF_ENUM(SecuritySessionId) {
    noSecuritySession                      = 0,     /* definitely not a valid SecuritySessionId */
    callerSecuritySession = ((SecuritySessionId)-1)     /* the Session I (the caller) am in */
};


/*!
    @enum SessionAttributeBits
    Each Session has a set of attribute bits. You can get those from the
        SessionGetInfo API function.
 */
typedef CF_OPTIONS(UInt32, SessionAttributeBits) {
    sessionIsRoot                          = 0x0001, /* is the root session (startup/system programs) */
    sessionHasGraphicAccess                = 0x0010, /* graphic subsystem (CoreGraphics et al) available */
    sessionHasTTY                          = 0x0020, /* /dev/tty is available */
    sessionIsRemote                        = 0x1000, /* session was established over the network */
};


/*!
    @enum SessionCreationFlags
    These flags control how a new session is created by SessionCreate.
        They have no permanent meaning beyond that.
 */
typedef CF_OPTIONS(UInt32, SessionCreationFlags) {
    sessionKeepCurrentBootstrap             = 0x8000 /* caller has allocated sub-bootstrap (expert use only) */
};
 
 
/*!
	@enum SessionStatus
	Error codes returned by AuthSession API.
    Note that the AuthSession APIs can also return Authorization API error codes.
*/
CF_ENUM(OSStatus) {
    errSessionSuccess                       = 0,      /* all is well */
    errSessionInvalidId                     = -60500, /* invalid session id specified */
    errSessionInvalidAttributes             = -60501, /* invalid set of requested attribute bits */
    errSessionAuthorizationDenied           = -60502, /* you are not allowed to do this */
    errSessionValueNotSet                   = -60503, /* the session attribute you requested has not been set */

    errSessionInternal                      = errAuthorizationInternal,	/* internal error */
	errSessionInvalidFlags                  = errAuthorizationInvalidFlags /* invalid flags/options */
};


/*!
    @function SessionGetInfo
    Obtain information about a session. You can ask about any session whose
	identifier you know. Use the callerSecuritySession constant to ask about
	your own session (the one your process is in).

    @param session (input) The Session you are asking about. Can be one of the
        special constants defined above.
	
	@param sessionId (output/optional) The actual SecuritySessionId for the session you asked about.
        Will never be one of those constants.
        
    @param attributes (output/optional) Receives the attribute bits for the session.

    @result An OSStatus indicating success (errSecSuccess) or an error cause.
    
    errSessionInvalidId -60500 Invalid session id specified

*/
OSStatus SessionGetInfo(SecuritySessionId session,
    SecuritySessionId * __nullable sessionId,
    SessionAttributeBits * __nullable attributes);
    

/*!
    @function SessionCreate
    This (very specialized) function creates a security session.
	Upon completion, the new session contains the calling process (and none other).
	You cannot create a session for someone else, and cannot avoid being placed
	into the new session. This is (currently) the only call that changes a process's
	session membership.
    By default, a new bootstrap subset port is created for the calling process. The process
    acquires this new port as its bootstrap port, which all its children will inherit.
    If you happen to have created the subset port on your own, you can pass the
    sessionKeepCurrentBootstrap flag, and SessionCreate will use it. Note however that
    you cannot supersede a prior SessionCreate call that way; only a single SessionCreate
    call is allowed for each Session (however made).
	This call will discard any security information established for the calling process.
	In particular, any authorization handles acquired will become invalid, and so will any
	keychain related information. We recommend that you call SessionCreate before
	making any other security-related calls that establish rights of any kind, to the
	extent this is practical. Also, we strongly recommend that you do not perform
	security-related calls in any other threads while calling SessionCreate.
    
    @param flags Flags controlling how the session is created.
    
    @param attributes The set of attribute bits to set for the new session.
        Not all bits can be set this way.
    
    @result An OSStatus indicating success (errSecSuccess) or an error cause.
    
    errSessionInvalidAttributes -60501 Attempt to set invalid attribute bits	
    errSessionAuthorizationDenied -60502 Attempt to re-initialize a session
    errSessionInvalidFlags -60011 Attempt to specify unsupported flag bits
    
*/
OSStatus SessionCreate(SessionCreationFlags flags,
    SessionAttributeBits attributes);

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* ! __AuthSession__ */
