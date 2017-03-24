/*
 * Copyright (c) 2010-2012 Apple Inc. All Rights Reserved.
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

#ifndef _SEC_TRANSFORM_H__
#define _SEC_TRANSFORM_H__

#include <CoreFoundation/CoreFoundation.h>

CF_EXTERN_C_BEGIN
CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
	@header
	
	To better follow this header, you should understand the following
	terms:
	
	Transform		A transform converts data from one form to another.
					Digests, encryption and decryption are all examples
					of transforms.  Each transform performs a single
					operation.
	Transform
	Group			A transform group is a directed (typically) acyclic 
					graph of transforms. Results from a transform flow 
					to the next Transform in the graph, and so on until 
					the end of the graph is reached. 
	
	Attribute		Transforms may have one or more attributes.  These
					attributes are parameters for the transforms and
					may affect the operation of the transform.  The value
					of an attribute may be set with static data or from
					the value of an attribute in another transform
					by connecting the attributes using the 
					SecTransformConnectTransforms API.
	
	External
	Representation	Transforms may be created programmatically or from
					an external representation.  External representations
					may be created from existing transforms.
	
	There are many types of transforms available.  These are documented
	in their own headers.  The functions in this header are applicable
	to all transforms.
	
*/

			
/*!
	@constant kSecTransformErrorDomain 
			The domain for CFErrorRefs created by Transforms
 */
CF_EXPORT const CFStringRef kSecTransformErrorDomain;

/*!
	@constant kSecTransformPreviousErrorKey
			If multiple errors occurred, the CFErrorRef that
			is returned from a Transfo]rm API will have a userInfo
			dictionary and that dictionary will have the previous
			error keyed by the kSecTransformPreviousErrorKey.
 */
CF_EXPORT const CFStringRef kSecTransformPreviousErrorKey;

/*!
	@constant kSecTransformAbortOriginatorKey
			The value of this key will be the transform that caused
			the transform chain to abort.
*/
CF_EXPORT const CFStringRef kSecTransformAbortOriginatorKey;


/****************	Transform Error Codes   ****************/
/*!
	@enum Security Transform Error Codes
	@discussion
	@const kSecTransformErrorAttributeNotFound
				The attribute was not found.
						
	@const kSecTransformErrorInvalidOperation
				An invalid operation was attempted.
				
	@const kSecTransformErrorNotInitializedCorrectly
				A required initialization is missing. It
				is most likely a missing required attribute.
				
	@const kSecTransformErrorMoreThanOneOutput
				A transform has an internal routing error
				that has caused multiple outputs instead 
				of a single discrete output.  This will
				occur if SecTransformExecute has already 
				been called.
				
	@const kSecTransformErrorInvalidInputDictionary
				A dictionary given to 
				SecTransformCreateFromExternalRepresentation has invalid data.
				
	@const kSecTransformErrorInvalidAlgorithm
				A transform that needs an algorithm as an attribute
				i.e the Sign and Verify transforms, received an invalid 
				algorithm.
				
	@const kSecTransformErrorInvalidLength
				A transform that needs a length such as a digest 
				transform has been given an invalid length.
				
	@const kSecTransformErrorInvalidType
				An invalid type has been set on an attribute.
				
	@const kSecTransformErrorInvalidInput
				The input set on a transform is invalid. This can
				occur if the data set for an attribute does not
				meet certain requirements such as correct key 
				usage for signing data.
				
	@const kSecTransformErrorNameAlreadyRegistered
				A custom transform of a particular name has already
				been registered.
				
	@const kSecTransformErrorUnsupportedAttribute
				An illegal action such as setting a read only 
				attribute has occurred.
	
	@const kSecTransformOperationNotSupportedOnGroup
				An illegal action on a group transform such as
				trying to call SecTransformSetAttribute has occurred.
				
	@const kSecTransformErrorMissingParameter
				A transform is missing a required attribute.

	@const kSecTransformErrorInvalidConnection
				A SecTransformConnectTransforms was called with
				transforms in different groups.
				
	@const kSecTransformTransformIsExecuting
				An illegal operation was called on a Transform
				while it was executing.  Please see the sequencing documentation
				in the discussion area of the SecTransformExecute API
 
	@const kSecTransformInvalidOverride
				An illegal override was given to a custom transform
 
	@const kSecTransformTransformIsNotRegistered
				A custom transform was asked to be created but the transform
				has not been registered.
				
	@const kSecTransformErrorAbortInProgress
				The abort attribute has been set and the transform is in the
				process of shutting down
				
	@const kSecTransformErrorAborted
				The transform was aborted.  
 
	@const kSecTransformInvalidArgument
				An invalid argument was given to a Transform API
				
						
*/

CF_ENUM(CFIndex)
{
	kSecTransformErrorAttributeNotFound = 1,
	kSecTransformErrorInvalidOperation = 2,
	kSecTransformErrorNotInitializedCorrectly = 3,
	kSecTransformErrorMoreThanOneOutput = 4,
	kSecTransformErrorInvalidInputDictionary = 5,
	kSecTransformErrorInvalidAlgorithm = 6,
	kSecTransformErrorInvalidLength = 7,
	kSecTransformErrorInvalidType = 8,
	kSecTransformErrorInvalidInput = 10,
  	kSecTransformErrorNameAlreadyRegistered = 11,
  	kSecTransformErrorUnsupportedAttribute = 12,
	kSecTransformOperationNotSupportedOnGroup = 13,
	kSecTransformErrorMissingParameter = 14,
	kSecTransformErrorInvalidConnection = 15,
	kSecTransformTransformIsExecuting = 16,
	kSecTransformInvalidOverride = 17,
	kSecTransformTransformIsNotRegistered = 18,
	kSecTransformErrorAbortInProgress = 19,
	kSecTransformErrorAborted = 20,
	kSecTransformInvalidArgument = 21
	
};

typedef CFTypeRef SecTransformRef;
typedef CFTypeRef SecGroupTransformRef;

/*!
	@function SecTransformGetTypeID
	@abstract Return the CFTypeID for a SecTransform.
	@result The CFTypeID
*/

CF_EXPORT CFTypeID SecTransformGetTypeID(void);

/*!
	@function SecGroupTransformGetTypeID
	@abstract Return the CFTypeID for a SecTransformGroup.
	@result The CFTypeID
*/


CF_EXPORT CFTypeID SecGroupTransformGetTypeID(void);


/****************	Transform Attribute Names  ****************/
/*!
	@constant kSecTransformInputAttributeName
		The name of the input attribute.
 */
CF_EXPORT const CFStringRef kSecTransformInputAttributeName __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
	@constant kSecTransformOutputAttributeName
		The name of the output attribute.
 */
CF_EXPORT const CFStringRef kSecTransformOutputAttributeName __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
	@constant kSecTransformDebugAttributeName
		Set this attribute to a CFWriteStream.
		This will signal the transform to write debugging 
		information to the stream.
		If this attribute is set to kCFBooleanTrue then
		the debugging data will be written out to
		stderr.
 */
CF_EXPORT const CFStringRef kSecTransformDebugAttributeName __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
	@constant kSecTransformTransformName
		The name of the transform.
*/
CF_EXPORT const CFStringRef kSecTransformTransformName __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
	@constant kSecTransformAbortAttributeName
		The name of the abort attribute.
 */
CF_EXPORT const CFStringRef kSecTransformAbortAttributeName __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
	@function			SecTransformCreateFromExternalRepresentation
	
	@abstract			Creates a transform instance from a CFDictionary of
						parameters.
						
	@param dictionary	The dictionary of parameters.
	
	@param error		An optional pointer to a CFErrorRef. This value is 
						set if an error occurred.  If not NULL the caller is 
						responsible for releasing the CFErrorRef. 
						
	@result				A pointer to a SecTransformRef object.  You
	  					must release the object with CFRelease when you are done
						with it. A NULL will be returned if an error occurred during 
						initialization, and if the error parameter 
						is non-null, it contains the specific error data.
						
*/
CF_EXPORT __nullable
SecTransformRef SecTransformCreateFromExternalRepresentation(
								CFDictionaryRef dictionary,
								CFErrorRef *error) 
								__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
	@function 			SecTransformCopyExternalRepresentation
	
	@abstract			Create a CFDictionaryRef that contains enough
						information to be able to recreate a transform.
						
	@param transformRef	The transformRef to be externalized.
	
	@discussion			This function returns a CFDictionaryRef that contains
						sufficient information to be able to recreate this
						transform.  You can pass this CFDictionaryRef to
						SecTransformCreateFromExternalRepresentation 
						to be able to recreate the transform.  The dictionary
						can also be written out to disk using the techniques
						described here.
						
http://developer.apple.com/mac/library/documentation/CoreFoundation/Conceptual/CFPropertyLists/Articles/Saving.html
*/

CF_EXPORT 
CFDictionaryRef SecTransformCopyExternalRepresentation(
							   SecTransformRef transformRef) 
							__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
	@function			SecTransformCreateGroupTransform
	
	@abstract			Create a SecGroupTransformRef that acts as a 
						container for a set of connected transforms.
						
	@result				A reference to a SecGroupTransform.
						
	@discussion			A SecGroupTransformRef is a container for all of
						the transforms that are in a directed graph.  
						A SecGroupTransformRef can be used with 
						SecTransformExecute, SecTransformExecuteAsync
						and SecTransformCopyExternalRepresentation
						APIs. While the intention is that a 
						SecGroupTransformRef willwork just like a S
						SecTransformRef that is currently not the case.  
						Using a SecGroupTransformRef with the 
						SecTransformConnectTransforms, 
						SecTransformSetAttribute and 
						SecTransformGetAttribute is undefined.
*/
CF_EXPORT 
SecGroupTransformRef SecTransformCreateGroupTransform(void);

/*!
	@function			SecTransformConnectTransforms
	
	@abstract			Pipe fitting for transforms.
	
	@param sourceTransformRef
						The transform that sends the data to the 
						destinationTransformRef.
						
	@param sourceAttributeName
						The name of the attribute in the sourceTransformRef that 
						supplies the data to the destinationTransformRef.
						Any attribute of the transform may be used as a source.  
	
	@param destinationTransformRef
						The transform that has one of its attributes
						be set with the data from the sourceTransformRef 
						parameter.
						
	@param destinationAttributeName
						The name of the attribute within the 
						destinationTransformRef whose data is set with the 
						data from the sourceTransformRef sourceAttributeName 
						attribute. Any attribute of the transform may be set. 
						
						
	@param group		In order to ensure referential integrity, transforms  
						are chained together into a directed graph and 
						placed into a group.  Each transform that makes up the 
						graph must be placed into the same group.  After
						a SecTransformRef has been placed into a group by
						calling the SecTransformConnectTransforms it may be
						released as the group will retain the transform.
						CFRelease the group after you execute
						it, or when you determine you will never execute it.
						
						In the example below, the output of trans1 is
						set to be the input of trans2.  The output of trans2
						is set to be the input of trans3.  Since the
						same group was used for the connections, the three
						transforms are in the same group.
						
<pre>
@textblock
						SecGroupTransformRef group =SecTransformCreateGroupTransform();
						CFErrorRef error = NULL;
						
						SecTransformRef trans1; // previously created using a 
												// Transform construction API
												// like SecEncryptTransformCreate
												
						SecTransformRef trans2;	// previously created using a 
												// Transform construction API
												// like SecEncryptTransformCreate
					
						SecTransformRef trans3; // previously created using a 
												// Transform construction API
												// like SecEncryptTransformCreate
						
						
						SecTransformConnectTransforms(trans1, kSecTransformOutputAttributeName,
													  trans2, kSecTransformInputAttributeName,
													  group, &error);
						
						SecTransformConnectTransforms(trans2, kSecTransformOutputAttributeName,
													  trans3, kSecTransformInputAttributeName.
													  group, &error);
						CFRelease(trans1);
						CFRelease(trans2);
						CFRelease(trans3);
						
						CFDataRef = (CFDataRef)SecTransformExecute(group, &error, NULL, NULL);
						CFRelease(group);					
@/textblock
</pre>
						
	@param error		An optional pointer to a CFErrorRef.  This value
						is set if an error occurred. If not NULL, the caller 
						is responsible for releasing the CFErrorRef.
						
	@result				The value returned is SecGroupTransformRef parameter.
	 					This will allow for chaining calls to 
						SecTransformConnectTransforms.			 
						
	@discussion			This function places transforms into a group by attaching
						the value of an attribute of one transform to the 
						attribute of another transform.  Typically the attribute 
						supplying the data is the kSecTransformAttrOutput 
						attribute but that is not a requirement.  It can be used to 
						set an attribute like Salt with the output attribute of 
						a random number transform. This function returns an 
						error and the named attribute will not be changed if 
						SecTransformExecute had previously been called on the 
						transform.
*/

CF_EXPORT __nullable
SecGroupTransformRef SecTransformConnectTransforms(SecTransformRef sourceTransformRef,
						   CFStringRef sourceAttributeName,
						   SecTransformRef destinationTransformRef,
				 		   CFStringRef destinationAttributeName,
						   SecGroupTransformRef group,
						   CFErrorRef *error)
						__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);
										
/*!
	@function			SecTransformSetAttribute
	
	@abstract			Set a static value as the value of an attribute in a 
						transform. This is useful for things like iteration 
						counts and other non-changing values.
	
	@param transformRef	The transform whose attribute is to be set.
	
	@param key			The name of the attribute to be set.
	
	@param value		The static value to set for the named attribute.
	
	@param error		An optional pointer to a CFErrorRef.  This value
						is set if an error occurred. If not NULL the caller 
						is responsible for releasing the CFErrorRef.
						
	@result				Returns true if the call succeeded. If an error occurred,
						the error parameter has more information
						about the failure case.
	
	@discussion			This API allows for setting static data into an 
						attribute for a transform.  This is in contrast to
						the SecTransformConnectTransforms function which sets derived
						data. This function will return an error and the 
						named attribute will not be changed if SecTransformExecute 
						has been called on the transform.
*/

CF_EXPORT 
Boolean SecTransformSetAttribute(SecTransformRef transformRef,
								CFStringRef key,
								CFTypeRef value,
								CFErrorRef *error)
								__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);
								
/*!
	@function			SecTransformGetAttribute
	
	@abstract			Get the current value of a transform attribute.
	
	@param transformRef	The transform whose attribute value will be retrieved.
	
	@param key			The name of the attribute to retrieve.
	
	@result				The value of an attribute.  If this attribute
						is being set as the output of another transform
						and SecTransformExecute has not been called on the
						transform or if the attribute does not exists
						then NULL will be returned.
						
	@discussion			This may be called after SecTransformExecute. 
*/

CF_EXPORT __nullable
CFTypeRef SecTransformGetAttribute(SecTransformRef transformRef,
								   CFStringRef key) 
								__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);								   

/*!
	@function			SecTransformFindByName
	
	@abstract			Finds a member of a transform group by its name.
	
	@param transform	The transform group to be searched.
	
	@param	name		The name of the transform to be found.
 
	@discussion			When a transform instance is created it will be given a
						unique name.  This name can be used to find that instance
						in a group.  While it is possible to change this unique
						name using the SecTransformSetAttribute API, developers
						should not do so.  This allows
						SecTransformFindTransformByName to work correctly.
	
	@result				The transform group member, or NULL if the member
						was not found.
*/

CF_EXPORT __nullable
SecTransformRef SecTransformFindByName(SecGroupTransformRef transform, 
								CFStringRef name)
								__OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);								   

/*!
	@function			SecTransformExecute
	
	@abstract			Executes a Transform or transform group synchronously.
	
	@param transformRef	The transform to execute.
	
	@param errorRef		An optional pointer to a CFErrorRef.  This value
						will be set if an error occurred during
						initialization or execution of the transform or group. 
						If not NULL the caller will be responsible for releasing 
						the returned CFErrorRef.						
						
	@result				This is the result of the transform. The specific value 
						is determined by the transform being executed.
						
	@discussion			There are two phases that occur when executing a 
						transform. The first phase checks to see if the tranforms
						have all of their required attributes set.
						If a GroupTransform is being executed, then a required 
						attribute for a transform is valid if it is connected
						to another attribute that supplies the required value.
						If any of the required attributes are not set or connected
						then SecTransformExecute will not run the transform but will 
						return NULL and the apporiate error is placed in the
						error parameter if it is not NULL.
					
						The second phase is the actual execution of the transform.
						SecTransformExecute executes the transform or 
						GroupTransform and when all of the processing is completed 
						it returns the result.  If an error occurs during 
						execution, then all processing will stop and NULL will be 
						returned and the appropriate error will be placed in the 
						error parameter if it is not NULL. 						
*/

CF_EXPORT CF_RETURNS_RETAINED
CFTypeRef SecTransformExecute(SecTransformRef transformRef, CFErrorRef* errorRef) 
						   __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA) CF_RETURNS_RETAINED;

/*!
	@typedef			SecMessageBlock
	
	@abstract			A SecMessageBlock is used by a transform instance to
						deliver messages during asynchronous operations.
						
	@param message		A CFType containing the message.  This is where
						either intermediate or final results are returned.
												
	@param error		If an error occurred, this will contain a CFErrorRef,
						otherwise this will be NULL. If not NULL the caller 
						is responsible for releasing the CFErrorRef.
						
	@param isFinal		If set the message returned is the final result 
						otherwise it is an intermediate result.
*/

typedef void (^SecMessageBlock)(CFTypeRef __nullable message, CFErrorRef __nullable error,
								Boolean isFinal);						
						
/*!
	@function			SecTransformExecuteAsync
	
	@abstract			Executes Transform or transform group asynchronously.
						
	
	@param transformRef	The transform to execute.
		
	@param deliveryQueue
						A dispatch queue on which to deliver the results of 
						this transform.  
	
	@param deliveryBlock
						A SecMessageBlock to asynchronously receive the 
						results of the transform. 
						
	@discussion			SecTransformExecuteAsync works just like the 
						SecTransformExecute API except that it 
						returns results to the deliveryBlock.  There 
						may be multple results depending on the transform.
						The block knows that the processing is complete
						when the isFinal parameter is set to true.  If an 
						error occurs the block's error parameter is
						set and the isFinal parameter will be set to
						true.
*/

CF_EXPORT
void SecTransformExecuteAsync(SecTransformRef transformRef,
							dispatch_queue_t deliveryQueue,
							SecMessageBlock deliveryBlock) 
						   __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END
CF_EXTERN_C_END

#endif /* _SEC_TRANSFORM_H__ */
