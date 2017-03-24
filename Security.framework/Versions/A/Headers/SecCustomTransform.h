/*
 * Copyright (c) 2010-2011,2014 Apple Inc. All Rights Reserved.
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

#ifndef _SEC_CUSTOM_TRANSFORM_H__
#define _SEC_CUSTOM_TRANSFORM_H__

#include <Security/SecTransform.h>

// Blocks are required for custom transforms
#ifdef __BLOCKS__

CF_EXTERN_C_BEGIN

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
    @header

    Custom transforms are an API that provides the ability to easily create new
    transforms. The essential functions of a transform are created in a
    collection of blocks. These blocks override the standard behavior of the
    base transform; a custom transform with no overrides is a null transform
    that merely passes through a data flow.

    A new transform type is created when calling the SecTransformRegister
    function which registers the name of the new transform and sets up its
    overrides. The SecTransformCreate function creates a new instance of a
    registered custom transform.

    A sample custom transform is provided here, along with a basic test program.
    This transform creates a Caesar cipher transform, one that simply adds a
    value to every byte of the plaintext.

    -----cut here-----
<pre>
@textblock
//
//  CaesarXform.c
//
//  Copyright (c) 2010-2011,2014 Apple Inc. All Rights Reserved.
//
//

#include <Security/SecCustomTransform.h>
#include <Security/SecTransform.h>

// This is the unique name for the custom transform type.
const CFStringRef kCaesarCipher = CFSTR("com.apple.caesarcipher");

// Name of the "key" attribute.
const CFStringRef kKeyAttributeName = CFSTR("key");

// Shortcut to return a CFError.
CFErrorRef invalid_input_error(void)
{
    return CFErrorCreate(kCFAllocatorDefault, kSecTransformErrorDomain,
                         kSecTransformErrorInvalidInput, NULL);
}

// =========================================================================
//  Implementation of the Transform instance
// =========================================================================
static SecTransformInstanceBlock CaesarImplementation(CFStringRef name,
                                            SecTransformRef newTransform,
                                            SecTransformImplementationRef ref)
{
   
    SecTransformInstanceBlock instanceBlock =
    ^{
        CFErrorRef result = NULL;

        // Every time a new instance of this custom transform class is
        // created, this block is called. This behavior means that any
        // block variables created in this block act like instance
        // variables for the new custom transform instance.
        __block int _key = 0;

        result = SecTransformSetAttributeAction(ref,
                                                kSecTransformActionAttributeNotification,
                                                kKeyAttributeName,
                                                ^(SecTransformAttributeRef name, CFTypeRef d)
            {
                CFNumberGetValue((CFNumberRef)d, kCFNumberIntType, &_key);
                return d;
            });

        if (result)
            return result;

        // Create an override that will be called to process the input
        // data into the output data
        result = SecTransformSetDataAction(ref,
                                           kSecTransformActionProcessData,
                                           ^(CFTypeRef d)
            {
                if (NULL == d)               // End of stream?
                    return (CFTypeRef) NULL; // Just return a null.

                char *dataPtr = (char *)CFDataGetBytePtr((CFDataRef)d);

                CFIndex dataLength = CFDataGetLength((CFDataRef)d);

                // Do the processing in memory.  There are better ways to do
                // this but for showing how custom transforms work this is fine.
                char *buffer = (char *)malloc(dataLength);
                if (NULL == buffer)
                    return (CFTypeRef) invalid_input_error();            // Return a CFErrorRef

                // Do the work of the caesar cipher (Rot(n))

                CFIndex i;
                for (i = 0; i < dataLength; i++)
                    buffer[i] = dataPtr[i] + _key;

                return (CFTypeRef)CFDataCreateWithBytesNoCopy(NULL, (UInt8 *)buffer,
                                                              dataLength, kCFAllocatorMalloc);
            });
        return result;
    };

    return Block_copy(instanceBlock);
}

SecTransformRef CaesarTransformCreate(CFIndex k, CFErrorRef* error)
{
    SecTransformRef caesarCipher;
    __block Boolean result = 1;
    static dispatch_once_t registeredOK = 0;

    dispatch_once(&registeredOK,
                  ^{
                     result = SecTransformRegister(kCaesarCipher, &CaesarImplementation, error);
                  });

    if (!result)
        return NULL;

    caesarCipher = SecTransformCreate(kCaesarCipher, error);
    if (NULL != caesarCipher)
    {
        CFNumberRef keyNumber =  CFNumberCreate(kCFAllocatorDefault,
                                                kCFNumberIntType, &k);
        SecTransformSetAttribute(caesarCipher, kKeyAttributeName,
                                 keyNumber, error);
        CFRelease(keyNumber);
    }

    return caesarCipher;
}


// The second function shows how to use custom transform defined in the
// previous function

// =========================================================================
//  Use a custom ROT-N (caesar cipher) transform
// =========================================================================
CFDataRef TestCaesar(CFDataRef theData, int rotNumber)
{
    CFDataRef result = NULL;
    CFErrorRef error = NULL;

    if (NULL == theData)
        return result;

    // Create an instance of the custom transform
    SecTransformRef caesarCipher = CaesarTransformCreate(rotNumber, &error);
    if (NULL == caesarCipher || NULL != error)
        return result;

    // Set the data to be transformed as the input to the custom transform
    SecTransformSetAttribute(caesarCipher,
                             kSecTransformInputAttributeName, theData, &error);

    if (NULL != error)
    {
        CFRelease(caesarCipher);
        return result;
    }

    // Execute the transform synchronously
    result = (CFDataRef)SecTransformExecute(caesarCipher, &error);
    CFRelease(caesarCipher);

    return result;
}

#include <CoreFoundation/CoreFoundation.h>

int main (int argc, const char *argv[])
{
    CFDataRef testData, testResult;
    UInt8 bytes[26];
    int i;

    // Create some test data, a string from A-Z

    for (i = 0; i < sizeof(bytes); i++)
        bytes[i] = 'A' + i;

    testData = CFDataCreate(kCFAllocatorDefault, bytes, sizeof(bytes));
    CFRetain(testData);
    CFShow(testData);

    // Encrypt the test data
    testResult = TestCaesar(testData, 3);

    CFShow(testResult);
    CFRelease(testData);
    CFRelease(testResult);
    return 0;
}
@/textblock
</pre>
	
*/

/****************	Custom Transform attribute metadata   ****************/

/*!
    @enum Custom Transform Attribute Metadata
    @discussion
            Within a transform, each of its attributes is a collection of
            "metadata attributes", of which name and current value are two. The
            value is directly visible from outside; the other metadata
            attributes direct the behavior of the transform and
            its function within its group. Each attribute may be tailored by setting its metadata.

    @const kSecTransformMetaAttributeValue
            The actual value of the attribute. The attribute value has a default
            value of NULL.

    @const kSecTransformMetaAttributeName
            The name of the attribute. Attribute name is read only and may
            not be used with the SecTransformSetAttributeBlock block.

    @const kSecTransformMetaAttributeRef
            A direct reference to an attribute's value. This reference allows
            for direct access to an attribute without having to look up the
            attribute by name.  If a transform commonly uses an attribute, using
            a reference speeds up the use of that attribute. Attribute
            references are not visible or valid from outside of the particular
            transform instance.

    @const kSecTransformMetaAttributeRequired
            Specifies if an attribute must have a non NULL value set or have an
            incoming connection before the transform starts to execute. This
            metadata has a default value of true for the input attribute, but
            false for all other attributes.

    @const kSecTransformMetaAttributeRequiresOutboundConnection
            Specifies if an attribute must have an outbound connection. This
            metadata has a default value of true for the output attribute but is
            false for all other attributes.

    @const kSecTransformMetaAttributeDeferred
            Determines if the AttributeSetNotification notification or the
            ProcessData blocks are deferred until SecExecuteTransform is called.
            This metadata value has a default value of true for the input
            attribute but is false for all other attributes.

    @const kSecTransformMetaAttributeStream
            Specifies if the attribute should expect a series of values ending
            with a NULL to specify the end of the data stream. This metadata has
            a default value of true for the input and output attributes, but is
            false for all other attributes.

    @const kSecTransformMetaAttributeCanCycle
            A Transform group is a directed graph which is typically acyclic.
            Some transforms need to work with cycles. For example, a transform
            that emits a header and trailer around the data of another transform
            must create a cycle. If this metadata set to true, no error is
            returned if a cycle is detected for this attribute.

    @const kSecTransformMetaAttributeExternalize
            Specifies if this attribute should be written out when creating the
            external representation of this transform. This metadata has a
            default value of true.

    @const kSecTransformMetaAttributeHasOutboundConnections
            This metadata value is true if the attribute has an outbound
            connection. This metadata is read only.

    @const kSecTransformMetaAttributeHasInboundConnection
            This metadata value is true if the attribute has an inbound
            connection. This metadata is read only.
*/

typedef CF_ENUM(CFIndex, SecTransformMetaAttributeType)
{
    kSecTransformMetaAttributeValue,
    kSecTransformMetaAttributeName,
    kSecTransformMetaAttributeRef,
    kSecTransformMetaAttributeRequired,
    kSecTransformMetaAttributeRequiresOutboundConnection,
    kSecTransformMetaAttributeDeferred,
    kSecTransformMetaAttributeStream,
    kSecTransformMetaAttributeCanCycle,
    kSecTransformMetaAttributeExternalize,
    kSecTransformMetaAttributeHasOutboundConnections,
    kSecTransformMetaAttributeHasInboundConnection
};

/*!
    @typedef        SecTransformAttributeRef

    @abstract       A direct reference to an attribute. Using an attribute
                    reference speeds up using an attribute's value by removing
                    the need to look
    it up by name.
*/
typedef CFTypeRef SecTransformAttributeRef;


/*!
    @typedef        SecTransformStringOrAttributeRef

    @abstract       This type signifies that either a CFStringRef or
                    a SecTransformAttributeRef may be used.
*/
typedef CFTypeRef SecTransformStringOrAttributeRef;


/*!
    @typedef        SecTransformActionBlock

    @abstract       A block that overrides the default behavior of a
                    custom transform.

    @result         If this block is used to overide the
                    kSecTransformActionExternalizeExtraData action then the
                    block should return a CFDictinaryRef of the custom
                    items to be exported. For all of other actions the
                    block should return NULL. If an error occurs for
                    any action, the block should return a CFErrorRef.

    @discussion     A SecTransformTransformActionBlock block is used to
                    override
                    the default behavior of a custom transform. This block is
                    associated with the SecTransformOverrideTransformAction
                    block.

                    The behaviors that can be overridden are:

                        kSecTransformActionCanExecute
                            Determine if the transform has all of the data
                            needed to run.

                        kSecTransformActionStartingExecution
                            Called just before running ProcessData.

                        kSecTransformActionFinalize
                            Called just before deleting the custom transform.

                        kSecTransformActionExternalizeExtraData
                            Called to allow for writing out custom data
                            to be exported.

                    Example:
<pre>
@textblock
                    SecTransformImplementationRef ref;
                    CFErrorRef error = NULL;

                    error = SecTransformSetTransformAction(ref, kSecTransformActionStartingExecution,
                    ^{
                        // This is where the work to initialize any data needed
                        // before running
                        CFErrorRef result = DoMyInitialization();
                        return result;
                    });

                    SecTransformTransformActionBlock actionBlock =
                    ^{
                        // This is where the work to clean up any existing data
                        // before running
                        CFErrorRef result = DoMyFinalization();
                        return result;
                    };

                    error = SecTransformSetTransformAction(ref, kSecTransformActionFinalize,
                        actionBlock);
@/textblock
</pre>
*/
typedef CFTypeRef __nullable (^SecTransformActionBlock)(void);

/*!
    @typedef        SecTransformAttributeActionBlock

    @abstract       A block used to override the default attribute handling
                    for when an attribute is set.

    @param attribute       The attribute whose default is being overridden or NULL
                    if this is a generic notification override

    @param value    Proposed new value for the attribute.

    @result         The new value of the attribute if successful. If an
                    error occurred then a CFErrorRef is returned. If a transform
                    needs to have a CFErrorRef as the value of an attribute,
                    then the CFErrorRef needs to be placed into a container such
                    as a CFArrayRef, CFDictionaryRef etc.

    @discussion     See the example program in this header for more details.

*/
typedef CFTypeRef __nullable (^SecTransformAttributeActionBlock)(
                                SecTransformAttributeRef attribute,
                                CFTypeRef value);
                                
/*!
    @typedef        SecTransformDataBlock
    
    @abstract       A block used to override the default data handling 
                    for a transform.

    @param data     The data to be processed. When this block is used
                    to to implement the kSecTransformActionProcessData action,
                    the data is the input data that is to be processed into the
                    output data.  When this block is used to implement the
                    kSecTransformActionInternalizeExtraData action, the data is
                    a CFDictionaryRef that contains the data that needs to be
                    imported.

    @result         When this block is used to implment the 
                    kSecTransformActionProcessData action, the value returned
                    is to be the data that will be passed to the output
                    attribute.  If an error occured while processing the input
                    data then the block should return a CFErrorRef.

                    When this block is used to implement the
                    kSecTransformActionInternalizeExtraData action then this block
                    should return NULL or a CFErrorRef if an error occurred.

    @discussion     See the example program for more details.
*/
typedef CFTypeRef __nullable (^SecTransformDataBlock)(CFTypeRef data);

/*!
    @typedef        SecTransformInstanceBlock

    @abstract       This is the block that is returned from an 
                    implementation of a CreateTransform function.

    @result         A CFErrorRef if an error occurred or NULL.
    
    @discussion     The instance block that is returned from the
                    developers CreateTransform function, defines 
                    the behavior of a custom attribute.  Please
                    see the example at the head of this file.

*/
typedef CFErrorRef __nullable (^SecTransformInstanceBlock)(void);

/*!
    @typedef        SecTransformImplementationRef

    @abstract       The SecTransformImplementationRef is a pointer to a block 
                    that implements an instance of a transform.

*/
typedef const struct OpaqueSecTransformImplementation* SecTransformImplementationRef;

/*!
    @function       SecTransformSetAttributeAction

    @abstract       Be notified when a attribute is set. The supplied block is
                    called when the attribute is set. This can be done for a
                    specific named attribute or all attributes.

    @param ref      A SecTransformImplementationRef that is bound to an instance
                    of a custom transform.

    @param action   The behavior to be set. This can be one of the following
                    actions: 

                    kSecTransformActionAttributeNotification - add a block that
                    is called when an attribute is set. If the name is NULL,
                    then the supplied block is called for all set attributes
                    except for ones that have a specific block as a handler.

                    For example, if there is a handler for the attribute "foo"
                    and for all attributes, the "foo" handler is called when the
                    "foo" attribute is set, but all other attribute sets will
                    call the NULL handler.

                    The kSecTransformActionProcessData action is a special case
                    of a SecTransformSetAttributeAction action.  If this is
                    called on the input attribute then it will overwrite any
                    kSecTransformActionProcessData that was set.

                    kSecTransformActionAttributeValidation Add a block that is
                    called to validate the input to an attribute.

    @param attribute
                    The name of the attribute that will be handled. An attribute
                    reference may also be given here. A NULL name indicates that
                    the supplied action is for all attributes.

    @param newAction
                    A SecTransformAttributeActionBlock which implements the
                    behavior.

    @result         A CFErrorRef if an error occured NULL otherwise.

    @discussion     This function may be called multiple times for either a
                    named attribute or for all attributes when the attribute
                    parameter is NULL. Each time the API is called it overwrites
                    what was there previously.

*/
CF_EXPORT __nullable
CFErrorRef SecTransformSetAttributeAction(SecTransformImplementationRef ref,
                                CFStringRef action,
                                SecTransformStringOrAttributeRef __nullable attribute,
                                SecTransformAttributeActionBlock newAction);
/*!
    @function       SecTransformSetDataAction

    @abstract       Change the way a custom transform will do data processing.
                    When the action parameter is kSecTransformActionProcessData
                    The newAction block will change the way that input data is
                    processed to become the output data. When the action
                    parameter is kSecTransformActionInternalizeExtraData it will
                    change the way a custom transform reads in data to be
                    imported into the transform.

    @param ref      A SecTransformImplementationRef that is bound to an instance
                    of a custom transform.

    @param action   The action being overridden.  This value should be one of the
                    following:
                        kSecTransformActionProcessData
                            Change the way that input data is processed into the
                            output data. The default behavior is to simply copy
                            the input data to the output attribute.

                            The kSecTransformActionProcessData action is really
                            a special case of a SecTransformSetAttributeAction
                            action. If you call this method with
                            kSecTransformActionProcessData it would overwrite
                            any kSecTransformActionAttributeNotification action
                            that was set proviously

                        kSecTransformActionInternalizeExtraData
                            Change the way that custom externalized data is
                            imported into the transform.  The default behavior
                            is to do nothing.

    @param newAction
                    A SecTransformDataBlock which implements the behavior.

                    If the action parameter is kSecTransformActionProcessData then
                    this block will be called to process the input data into the
                    output data.

                    if the action parameter is kSecTransformActionInternalizeExtraData then
                    this block will called to input custom data into the transform.

    @result         A CFErrorRef is an error occured NULL otherwise.

    @discussion      This API may be called multiple times.  Each time the API is called 
                    it overwrites what was there previously.

*/
CF_EXPORT __nullable
CFErrorRef SecTransformSetDataAction(SecTransformImplementationRef ref,
                                    CFStringRef action,
                                    SecTransformDataBlock newAction);

/*
    @function       SecTransformSetTransformAction

    @abstract       Change the way that transform deals with transform lifecycle
                    behaviors.

    @param ref      A SecTransformImplementationRef that is bound to an instance
                    of a custom transform. It provides the neccessary context
                    for making the call to modify a custom transform.

    @param action   Defines what behavior will be changed.  The possible values
                    are:

                        kSecTransformActionCanExecute
                            A CanExecute block is called before the transform
                            starts to execute. Returning NULL indicates that the
                            transform has all necessary parameters set up to be
                            able to execute. If there is a condition that
                            prevents this transform from executing, return a
                            CFError. The default behavior is to return NULL.

                        kSecTransformActionStartingExecution
                            A StartingExecution block is called as a transform
                            starts execution but before any input is delivered.
                            Transform-specific initialization can be performed
                            in this block.

                        kSecTransformActionFinalize
                            A Finalize block is called before a transform is
                            released. Any final cleanup can be performed in this
                            block.

                        kSecTransformActionExternalizeExtraData
                            An ExternalizeExtraData block is called before a
                            transform is externalized. If there is any extra
                            work that the transform needs to do (e.g. copy data
                            from local variables to attributes) it can be
                            performed in this block.

    @param newAction
                    A SecTransformTransformActionBlock which implements the behavior.

    @result         A CFErrorRef if an error occured NULL otherwise.
        
*/
CF_EXPORT __nullable
CFErrorRef SecTransformSetTransformAction(SecTransformImplementationRef ref,
                                CFStringRef action, 
                                SecTransformActionBlock newAction);

/*!
 @function       SecTranformCustomGetAttribute
 
 @abstract       Allow a custom transform to get an attribute value
 
 @param ref      A SecTransformImplementationRef that is bound to an instance
 of a custom transform.
 
 @param attribute
 The name or the attribute handle of the attribute whose
 value is to be retrieved.
 
 @param type     The type of data to be retrieved for the attribute.  See the 
 discussion on SecTransformMetaAttributeType for details.
 
 @result         The value of the attribute.
 
 */
CF_EXPORT __nullable
CFTypeRef SecTranformCustomGetAttribute(SecTransformImplementationRef ref, 
                                        SecTransformStringOrAttributeRef attribute,
                                        SecTransformMetaAttributeType type) AVAILABLE_MAC_OS_X_VERSION_10_7_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_8;

/*!
 @function       SecTransformCustomGetAttribute
 
 @abstract       Allow a custom transform to get an attribute value
 
 @param ref      A SecTransformImplementationRef that is bound to an instance
 of a custom transform.
 
 @param attribute
 The name or the attribute handle of the attribute whose
 value is to be retrieved.
 
 @param type     The type of data to be retrieved for the attribute.  See the 
 discussion on SecTransformMetaAttributeType for details.
 
 @result         The value of the attribute.
 
 */
CF_EXPORT __nullable
CFTypeRef SecTransformCustomGetAttribute(SecTransformImplementationRef ref, 
                                        SecTransformStringOrAttributeRef attribute,
                                        SecTransformMetaAttributeType type) __asm__("_SecTranformCustomGetAttribute");

/*!
    @function       SecTransformCustomSetAttribute

    @abstract       Allow a custom transform to set an attribute value

    @param ref      A SecTransformImplementationRef that is bound to an instance
                    of a custom transform.

    @param attribute
                    The name or the attribute handle of the attribute whose
                    value is to be set.

    @param type     The type of data to be retrieved for the attribute.  See the
                    discussion on SecTransformMetaAttributeType for details.

    @param value    The new value for the attribute

    @result         A CFErrorRef if an error occured , NULL otherwise.

    @discussion     Unlike the SecTransformSetAttribute API this API can set 
                    attribute values while a transform is executing.  These
                    values are limited to the custom transform instance that
                    is bound to the ref parameter.

*/
CF_EXPORT __nullable
CFTypeRef SecTransformCustomSetAttribute(SecTransformImplementationRef ref,
                                    SecTransformStringOrAttributeRef attribute,
                                    SecTransformMetaAttributeType type,
                                    CFTypeRef __nullable value);
/*!
    @function       SecTransformPushbackAttribute

    @abstract       Allows for putting a single value back for a specific
                    attribute.  This will stop the flow of data into the
                    specified attribute until any attribute is changed for the
                    transform instance bound to the ref parameter.

    @param ref      A SecTransformImplementationRef that is bound to an instance
                    of a custom transform.

    @param attribute
                    The name or the attribute handle of the attribute whose
                    value is to be pushed back.

    @param value    The value being pushed back.

    @result         A CFErrorRef if an error occured , NULL otherwise.

*/
CF_EXPORT __nullable
CFTypeRef SecTransformPushbackAttribute(SecTransformImplementationRef ref,
                                SecTransformStringOrAttributeRef attribute,
                                CFTypeRef value);

/*!
    @typedef        SecTransformCreateFP

    @abstract       A function pointer to a function that will create a
                    new instance of a custom transform.

    @param name     The name of the new custom transform. This name MUST be
                    unique.

    @param newTransform
                    The newly created transform Ref.

    @param ref      A reference that is bound to an instance of a custom
                    transform.

    @result         A SecTransformInstanceBlock that is used to create a new
                    instance of a custom transform.

    @discussion      The CreateTransform function creates a new transform. The
                    SecTransformInstanceBlock that is returned from this
                    function provides the implementation of all of the overrides
                    necessary to create the custom transform. This returned
                    SecTransformInstanceBlock is also where the "instance"
                    variables for the custom transform may be defined. See the
                    example in the header section of this file for more detail.
*/

typedef SecTransformInstanceBlock __nonnull (*SecTransformCreateFP)(CFStringRef name,
                            SecTransformRef newTransform, 
                            SecTransformImplementationRef ref);

/************** custom Transform transform override actions   **************/

/*!
    @constant  kSecTransformActionCanExecute
                Overrides the standard behavior that checks to see if all of the
                required attributes either have been set or are connected to
                another transform.  When overriding the default behavior the
                developer can decided what the necessary data is to have for a
                transform to be considered 'ready to run'.  Returning NULL means
                that the transform is ready to be run. If the transform is NOT
                ready to run then the override should return a CFErrorRef
                stipulating the error.
 */
CF_EXPORT const CFStringRef kSecTransformActionCanExecute;
/*!
    @constant  kSecTransformActionStartingExecution
                Overrides the standard behavior that occurs just before starting
                execution of a custom transform. This is typically overridden
                to allow for initialization. This is used with the
                SecTransformOverrideTransformAction block.
 */
CF_EXPORT const CFStringRef kSecTransformActionStartingExecution;

/*!
    @constant kSecTransformActionFinalize
                Overrides the standard behavior that occurs just before deleting
                a custom transform. This is typically overridden to allow for
                memory clean up of a custom transform.  This is used with the
                SecTransformOverrideTransformAction block.
 */
CF_EXPORT const CFStringRef kSecTransformActionFinalize;

/*!

    @constant kSecTransformActionExternalizeExtraData
                Allows for adding to the data that is stored using an override
                to the kSecTransformActionExternalizeExtraData block. The output
                of this override is a dictionary that contains the custom
                externalized data. A common use of this override is to write out
                a version number of a custom transform.
 */
CF_EXPORT const CFStringRef kSecTransformActionExternalizeExtraData;

/*!
    @constant  kSecTransformActionProcessData
                Overrides the standard data processing for an attribute. This is
                almost exclusively used for processing the input attribute as
                the return value of their block sets the output attribute. This
                is used with the SecTransformOverrideAttributeAction block.
 */
CF_EXPORT const CFStringRef kSecTransformActionProcessData;

/*!
    @constant kSecTransformActionInternalizeExtraData
                Overrides the standard processing that occurs when externalized
                data is used to create a transform.  This is closely tied to the
                kSecTransformActionExternalizeExtraData override. The 'normal'
                attributes are read into the new transform and then this is
                called to read in the items that were written out using
                kSecTransformActionExternalizeExtraData override. A common use
                of this override would be to read in the version number of the
                externalized custom transform.
 */
CF_EXPORT const CFStringRef kSecTransformActionInternalizeExtraData;

/*!
    @constant SecTransformActionAttributeNotification
                Allows a block to be called when an attribute is set.  This
                allows for caching the value as a block variable in the instance
                block or transmogrifying the data to be set. This action is
                where a custom transform would be able to do processing outside
                of processing input to output as process data does.  One the
                data has been processed the action block can call
                SecTransformCustomSetAttribute to update and other attribute.
 */
CF_EXPORT const CFStringRef kSecTransformActionAttributeNotification;

/*!
    @constant kSecTransformActionAttributeValidation
                Allows a block to be called to validate the new value for an
                attribute.  The default is no validation and any CFTypeRef can
                be used as the new value.  The block should return NULL if the
                value is ok to set on the attribute or a CFErrorRef otherwise.

*/
CF_EXPORT const CFStringRef kSecTransformActionAttributeValidation;

/*!
    @function       SecTransformRegister

    @abstract       Register a new custom transform so that it may be used to 
                    process data

    @param uniqueName   
                    A unique name for this custom transform.  It is recommended
                    that a reverse DNS name be used for the name of your custom
                    transform

    @param createTransformFunction  
                    A SecTransformCreateFP function pointer. The function must
                    return a SecTransformInstanceBlock block that block_copy has
                    been called on before returning the block. Failure to call
                    block_copy will cause undefined behavior.

    @param error    This pointer is set if an error occurred.  This value 
                    may be NULL if you do not want an error returned.

    @result         True if the custom transform was registered false otherwise

*/
CF_EXPORT
Boolean SecTransformRegister(CFStringRef uniqueName, 
                                    SecTransformCreateFP createTransformFunction,
                                    CFErrorRef* error)
                            __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
     @function      SecTransformCreate

     @abstract      Creates a transform computation object.

     @param name    The type of transform to create, must have been registered
                    by SecTransformRegister, or be a system pre-defined
                    transform type.

     @param error   A pointer to a CFErrorRef.  This pointer is set if an error
                    occurred.  This value may be NULL if you do not want an
                    error returned.

     @result        A pointer to a SecTransformRef object.  This object must be
                    released with CFRelease when you are done with it.  This
                    function returns NULL if an error occurred.
 */
CF_EXPORT __nullable
SecTransformRef SecTransformCreate(CFStringRef name, CFErrorRef *error)
                            __OSX_AVAILABLE_STARTING(__MAC_10_7,__IPHONE_NA);

/*!
    @Function       SecTransformNoData

    @abstract       Returns back A CFTypeRef from inside a processData
                    override that says that while no data is being returned
                    the transform is still active and awaiting data.

    @result         A 'special' value that allows that specifies that the
                    transform is still active and awaiting data.

    @discussion      The standard behavior for the ProcessData override is that
                    it will receive a CFDataRef and it processes that data and
                    returns a CFDataRef that contains the processed data. When
                    there is no more data to process the ProcessData override
                    block is called one last time with a NULL CFDataRef.  The
                    ProcessData block should/must return the NULL CFDataRef to
                    complete the processing.  This model does not work well for
                    some transforms. For example a digest transform needs to see
                    ALL of the data that is being digested before it can send
                    out the digest value.
                    
                    If a ProcessData block has no data to return, it can return
                    SecTransformNoData(), which informs the transform system
                    that there is no data to pass on to the next transform.


*/
CF_EXPORT
CFTypeRef SecTransformNoData(void);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

CF_EXTERN_C_END

#endif // __BLOCKS__
#endif // _SEC_CUSTOM_TRANSFORM_H__
