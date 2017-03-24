/*
 * Copyright (c) 2001-2002,2004,2011-2012,2014 Apple Inc. All Rights Reserved.
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
 *  AuthorizationPlugin.h
 *  AuthorizationPlugin -- APIs for implementing authorization plugins.
 */

#ifndef _SECURITY_AUTHORIZATIONPLUGIN_H_
#define _SECURITY_AUTHORIZATIONPLUGIN_H_

#include <Security/Authorization.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@header AuthorizationPlugin
	
	The AuthorizationPlugin API allows the creation of plugins that can participate
	in authorization decisions.  Using the AuthorizationDB API the system can be configured
	to use these plugins.  Plugins are loaded into a separate process, the pluginhost, to 
	isolate the process of authorization from the client.  There are two types of pluginhosts.
	One runs as an anonymous user and can be used to communicate with the user, for example
	to ask for a password.  Another one runs with root privileges to perform privileged
	operations that may be required.

    A typical use is to implement additional policies that cannot be expressed in the
    authorization configuration.
    
    Plugins implement a handshake function called AuthorizationPluginCreate with which
    their interface (AuthorizationPluginInterface) and the engine's interface
    (AuthorizationCallbacks) are exchanged.  Plugins are asked to create 
    Mechanisms, which are the basic element as authorizations are performed.  
    
    Mechanisms are invoked when it is time for them to make a decision.  A decision is 
    made by setting a single result (AuthorizationResult).  Mechanisms in the 
    authorization can communicate auxiliary information by setting and/or getting hints 
    and setting and/or getting context data.  Hints are advisory and don't need to be
    looked at, nor are they preserved as part of the authorization result. Context data
    becomes part of the result of the authorization.
    
    Context data is tagged with a flag that describes whether the information is returned
    to the authorization client upon request (AuthorizationCopyInfo() in Authorization.h)
    or whether it's private to the mechanisms making a decision.
    
*/


/*!
	@typedef AuthorizationValue
    Auxiliary data is passed between the engine and the mechanism as AuthorizationValues
*/
typedef struct AuthorizationValue
{
    size_t length;
    void *data;
} AuthorizationValue;

/*!
    @typedef AuthorizationValueVector
    A vector of AuthorizationValues.  Used to communicate arguments passed from the 
    configuration file <code>authorization(5)</code>.
*/
typedef struct AuthorizationValueVector
{
	UInt32 count;
	AuthorizationValue *values;
} AuthorizationValueVector;

/*!
    @typedef
    Data produced as context during the authorization evaluation is tagged.  
    If data is set to be extractable (kAuthorizationContextFlagExtractable), it will be possible for the client of authorization to obtain the value of this attribute using AuthorizationCopyInfo().
    If data is marked as volatile (kAuthorizationContextFlagVolatile), this value will not be remembered in the AuthorizationRef.
    Sticky data (kAuthorizationContextFlagSticky) persists through a failed or interrupted evaluation. It can be used to propagate an error condition from a downstream plugin to an upstream one. It is not remembered in the AuthorizationRef.
*/
typedef CF_OPTIONS(UInt32, AuthorizationContextFlags)
{
    kAuthorizationContextFlagExtractable = (1 << 0),
    kAuthorizationContextFlagVolatile = (1 << 1),
    kAuthorizationContextFlagSticky = (1 << 2)
};


/*!
	@typedef AuthorizationMechanismId
    The mechanism id specified in the configuration is passed to the plugin to create the appropriate mechanism.
*/
typedef const AuthorizationString AuthorizationMechanismId;

/*!
    @typedef AuthorizationPluginId
	Not used by plugin writers.  Loaded plugins are identified by their name.
 */
typedef const AuthorizationString AuthorizationPluginId;

/*!
	@typedef AuthorizationPluginRef
	Handle passed back by the plugin writer when creating a plugin.  Any pluginhost will only instantiate one instance.  The handle is used when creating mechanisms.
*/
typedef void *AuthorizationPluginRef;

/*!
	@typedef AuthorizationMechanismRef
	Handle passed back by the plugin writer when creating an an instance of a mechanism in a plugin.  One instance will be created for any authorization.
*/
typedef void *AuthorizationMechanismRef;

/*!
	@typedef AuthorizationEngineRef
	Handle passed from the engine to an instance of a mechanism in a plugin (corresponds to a particular AuthorizationMechanismRef).
*/
typedef struct __OpaqueAuthorizationEngine *AuthorizationEngineRef;

/*!
	@typedef AuthorizationSessionId
	A unique value for an AuthorizationSession being evaluated, provided by the authorization engine.
    A session is represented by a top level call to an Authorization API.
*/
typedef void *AuthorizationSessionId;

/*!
    @enum AuthorizationResult
	Possible values for SetResult() in AuthorizationCallbacks.
    
    @constant kAuthorizationResultAllow the operation succeeded and authorization should be granted as far as this mechanism is concerned.
    @constant kAuthorizationResultDeny the operation succeeded but authorization should be denied as far as this mechanism is concerned.
    @constant kAuthorizationResultUndefined the operation failed for some reason and should not be retried for this session.
    @constant kAuthorizationResultUserCanceled the user has requested that the evaluation be terminated.
*/
typedef CF_ENUM(UInt32, AuthorizationResult) {
    kAuthorizationResultAllow,
    kAuthorizationResultDeny,
    kAuthorizationResultUndefined,
    kAuthorizationResultUserCanceled,
};

/*!
    @enum
    Version of the interface (AuthorizationPluginInterface) implemented by the plugin.
    The value is matched to the definition in this file.
*/
enum {
    kAuthorizationPluginInterfaceVersion = 0
};

/*!
    @enum
    Version of the callback structure (AuthorizationCallbacks) passed to the plugin.
    The value is matched to the definition in this file.  The engine may provide a newer
    interface.
*/
enum {
    kAuthorizationCallbacksVersion = 1
};


/*!
    @struct
    Callback API provided by the AuthorizationEngine. 
    
    @field version      Engine callback version.
    @field SetResult    Set a result after a call to AuthorizationSessionInvoke.
    @field RequestInterrupt Request authorization engine to interrupt all mechamisms invoked after this mechamism has called SessionSetResult and then call AuthorizationSessionInvoke again.
    @field DidDeactivate    Respond to the Deactivate request.
    @field GetContextValue  Read value from context.  AuthorizationValue does not own data.
    @field SetContextValue  Write value to context.  AuthorizationValue and data are copied.
    @field GetHintValue     Read value from hints. AuthorizationValue does not own data.
    @field SetHintValue     Write value to hints.  AuthorizationValue and data are copied.
    @field GetArguments     Read arguments passed.  AuthorizationValueVector does not own data.
    @field GetSessionId     Read SessionId.
*/
typedef struct AuthorizationCallbacks {

    /* Engine callback version. */
    UInt32 version;

    /* Set a result after a call to AuthorizationSessionInvoke. */
    OSStatus (*SetResult)(AuthorizationEngineRef inEngine, AuthorizationResult inResult);

    /* Request authorization engine to interrupt all mechamisms invoked after 
        this mechamism has called SessionSetResult and then call 
        AuthorizationSessionInvoke again. */
    OSStatus (*RequestInterrupt)(AuthorizationEngineRef inEngine);
    
    /* Respond to the Deactivate request. */
    OSStatus (*DidDeactivate)(AuthorizationEngineRef inEngine);

    /* Read value from context.  AuthorizationValue does not own data. */
    OSStatus (*GetContextValue)(AuthorizationEngineRef inEngine,
        AuthorizationString inKey,
        AuthorizationContextFlags * __nullable outContextFlags,
        const AuthorizationValue * __nullable * __nullable outValue);

    /* Write value to context.  AuthorizationValue and data are copied. */
    OSStatus (*SetContextValue)(AuthorizationEngineRef inEngine,
        AuthorizationString inKey,
        AuthorizationContextFlags inContextFlags,
        const AuthorizationValue *inValue);

    /* Read value from hints. AuthorizationValue does not own data. */
    OSStatus (*GetHintValue)(AuthorizationEngineRef inEngine,
        AuthorizationString inKey,
        const AuthorizationValue * __nullable * __nullable outValue);

    /* Write value to hints.  AuthorizationValue and data are copied. */
    OSStatus (*SetHintValue)(AuthorizationEngineRef inEngine,
        AuthorizationString inKey,
        const AuthorizationValue *inValue);

    /* Read arguments passed.  AuthorizationValueVector does not own data. */
    OSStatus (*GetArguments)(AuthorizationEngineRef inEngine,
        const AuthorizationValueVector * __nullable * __nonnull outArguments);

    /* Read SessionId. */
    OSStatus (*GetSessionId)(AuthorizationEngineRef inEngine,
        AuthorizationSessionId __nullable * __nullable outSessionId);

    /* Read value from hints. AuthorizationValue does not own data. */
    OSStatus (*GetImmutableHintValue)(AuthorizationEngineRef inEngine,
        AuthorizationString inKey,
        const AuthorizationValue * __nullable * __nullable outValue);

} AuthorizationCallbacks;


/*!
    @struct
    Interface that must be implemented by each plugin. 
    
    @field version  Must be set to kAuthorizationPluginInterfaceVersion
    @field PluginDestroy    Plugin should clean up and release any resources it is holding.
    @field MechanismCreate  The plugin should create a mechanism named mechanismId.  The mechanism needs to use the AuthorizationEngineRef for the callbacks and pass back a   AuthorizationMechanismRef for itself.  MechanismDestroy will be called when it is no longer needed.
    @field MechanismInvoke  Invoke an instance of a mechanism.  It should call SetResult during or after returning from this function.
    @field MechanismDeactivate  Mechanism should respond with a DidDeactivate as soon as possible
    @field MechanismDestroy Mechanism should clean up and release any resources it is holding
*/
typedef struct AuthorizationPluginInterface
{
    /* Must be set to kAuthorizationPluginInterfaceVersion. */
    UInt32 version;

    /* Notify a plugin that it is about to be unloaded so it get a chance to clean up and release any resources it is holding.  */
    OSStatus (*PluginDestroy)(AuthorizationPluginRef inPlugin);

    /* The plugin should create a mechanism named mechanismId.  The mechanism needs to use the
        AuthorizationEngineRef for the callbacks and pass back an AuthorizationMechanismRef for
        itself.  MechanismDestroy will be called when it is no longer needed. */
    OSStatus (*MechanismCreate)(AuthorizationPluginRef inPlugin,
        AuthorizationEngineRef inEngine,
        AuthorizationMechanismId mechanismId,
        AuthorizationMechanismRef __nullable * __nonnull outMechanism);

    /* Invoke an instance of a mechanism.  It should call SetResult during or after returning from this function.  */
    OSStatus (*MechanismInvoke)(AuthorizationMechanismRef inMechanism);

    /* Mechanism should respond with a DidDeactivate as soon as possible. */
    OSStatus (*MechanismDeactivate)(AuthorizationMechanismRef inMechanism);

    /* Mechanism should clean up and release any resources it is holding. */
    OSStatus (*MechanismDestroy)(AuthorizationMechanismRef inMechanism);

} AuthorizationPluginInterface;


/*!
    @function AuthorizationPluginCreate

    Initialize a plugin after it gets loaded.  This is the main entry point to a plugin.  This function will only be called once.  
    After all Mechanism instances have been destroyed outPluginInterface->PluginDestroy will be called.

    @param callbacks (input) A pointer to an AuthorizationCallbacks which contains the callbacks implemented by the AuthorizationEngine.
    @param outPlugin (output) On successful completion should contain a valid AuthorizationPluginRef.  This will be passed in to any subsequent calls the engine makes to  outPluginInterface->MechanismCreate and outPluginInterface->PluginDestroy.
    @param outPluginInterface (output) On successful completion should contain a pointer to a AuthorizationPluginInterface that will stay valid until outPluginInterface->PluginDestroy is called. */
OSStatus AuthorizationPluginCreate(const AuthorizationCallbacks *callbacks,
    AuthorizationPluginRef __nullable * __nonnull outPlugin,
    const AuthorizationPluginInterface * __nullable * __nonnull outPluginInterface);

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* _SECURITY_AUTHORIZATIONPLUGIN_H_ */
