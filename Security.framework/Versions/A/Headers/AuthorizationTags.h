/*
 * Copyright (c) 2000-2004,2011,2014 Apple Inc. All Rights Reserved.
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
 *  AuthorizationTags.h -- Right tags for implementing access control in
 *  applications and daemons
 */

#ifndef _SECURITY_AUTHORIZATIONTAGS_H_
#define _SECURITY_AUTHORIZATIONTAGS_H_


/*!
	@header AuthorizationTags

	This header defines some of the supported rights tags to be used in the Authorization API.
*/


/*!
	@define kAuthorizationEnvironmentUsername
	The name of the AuthorizationItem that should be passed into the environment when specifying a username.  The value and valueLength should contain the username itself.
*/
#define kAuthorizationEnvironmentUsername  "username"

/*!
	@define kAuthorizationEnvironmentPassword
	The name of the AuthorizationItem that should be passed into the environment when specifying a password for a given username.  The value and valueLength should contain the actual password data.
*/
#define kAuthorizationEnvironmentPassword  "password"

/*!
	@define kAuthorizationEnvironmentShared
	The name of the AuthorizationItem that should be passed into the environment when specifying a username and password.  Adding this entry to the environment will cause the username/password to be added to the shared credential pool of the calling applications session.  This means that further calls by other applications in this session will automatically have this credential availible to them.  The value is ignored.
*/
#define kAuthorizationEnvironmentShared  "shared"

/*!
	@define kAuthorizationRightExecute
	The name of the AuthorizationItem that should be passed into the rights when preauthorizing for a call to AuthorizationExecuteWithPrivileges().
	
	You need to aquire this right to be able to perform a AuthorizationExecuteWithPrivileges() operation.  In addtion to this right you should obtain whatever rights the tool you are executing with privileges need to perform it's operation on your behalf.  Currently no options are supported but you should pass in the full path of the tool you wish to execute in the value and valueLength fields.  In the future we will limit the right to only execute the requested path, and we will display this information to the user.
*/
#define kAuthorizationRightExecute "system.privilege.admin"

/*!
	@define kAuthorizationEnvironmentPrompt
	The name of the AuthorizationItem that should be passed into the environment when specifying a invocation specific additional text.  The value should be a localized UTF8 string.
*/
#define kAuthorizationEnvironmentPrompt  "prompt"

/*!
	@define kAuthorizationEnvironmentIcon
	The name of the AuthorizationItem that should be passed into the environment when specifying an alternate icon to be used.  The value should be a full path to and image NSImage can deal with.
*/
#define kAuthorizationEnvironmentIcon  "icon"


#endif /* !_SECURITY_AUTHORIZATIONTAGS_H_ */
