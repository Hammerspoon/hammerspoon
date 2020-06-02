//
//  SentryCrashObjC.h
//
//  Created by Karl Stenerud on 2012-08-30.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#ifndef HDR_SentryCrashObjC_h
#define HDR_SentryCrashObjC_h

#ifdef __cplusplus
extern "C" {
#endif


#include <stdbool.h>
#include <stdint.h>


typedef enum
{
    SentryCrashObjCTypeUnknown = 0,
    SentryCrashObjCTypeClass,
    SentryCrashObjCTypeObject,
    SentryCrashObjCTypeBlock,
} SentryCrashObjCType;

typedef enum
{
    SentryCrashObjCClassTypeUnknown = 0,
    SentryCrashObjCClassTypeString,
    SentryCrashObjCClassTypeDate,
    SentryCrashObjCClassTypeURL,
    SentryCrashObjCClassTypeArray,
    SentryCrashObjCClassTypeDictionary,
    SentryCrashObjCClassTypeNumber,
    SentryCrashObjCClassTypeException,
} SentryCrashObjCClassType;

typedef struct
{
    const char* name;
    const char* type;
    int index;
} SentryCrashObjCIvar;


//======================================================================
#pragma mark - Basic Objective-C Queries -
//======================================================================

/** Check if a pointer is a tagged pointer or not.
 *
 * @param pointer The pointer to check.
 * @return true if it's a tagged pointer.
 */
bool sentrycrashobjc_isTaggedPointer(const void* const pointer);

/** Check if a pointer is a valid tagged pointer.
 *
 * @param pointer The pointer to check.
 * @return true if it's a valid tagged pointer.
 */
bool sentrycrashobjc_isValidTaggedPointer(const void* const pointer);

/** Query a pointer to see what kind of object it points to.
 * If the pointer points to a class, this method will verify that its basic
 * class data and ivars are valid,
 * If the pointer points to an object, it will verify the object data (if
 * recognized as a common class), and the isa's basic class info (everything
 * except ivars).
 *
 * Warning: In order to ensure that an object is both valid and accessible,
 *          always call this method on an object or class pointer (including
 *          those returned by sentrycrashobjc_isaPointer() and sentrycrashobjc_superclass())
 *          BEFORE calling any other function in this module.
 *
 * @param objectOrClassPtr Pointer to something that may be an object or class.
 *
 * @return The type of object, or SentryCrashObjCTypeNone if it was not an object or
 *         was inaccessible.
 */
SentryCrashObjCType sentrycrashobjc_objectType(const void* objectOrClassPtr);

/** Check that an object contains valid data.
 * If the object is of a recognized type (string, date, array, etc),
 * this function will verify that its internal data is intact.
 *
 * Call this function before calling any object-specific functions.
 *
 * @param object The object to verify.
 *
 * @return true if the object is valid.
 */
bool sentrycrashobjc_isValidObject(const void* object);

/** Fetch the isa pointer from an object or class.
 *
 * @param objectOrClassPtr Pointer to a valid object or class.
 *
 * @return The isa pointer.
 */
const void* sentrycrashobjc_isaPointer(const void* objectOrClassPtr);

/** Fetch the super class pointer from a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return the super class.
 */
const void* sentrycrashobjc_superClass(const void* classPtr);

/** Get the base class this class is derived from.
 * It will always return the highest level non-root class in the hierarchy
 * (one below NSObject or NSProxy), unless the passed in object or class
 * actually is a root class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return The base class.
 */
const void* sentrycrashobjc_baseClass(const void* const classPtr);

/** Check if a class is a meta class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return true if the class is a meta class.
 */
bool sentrycrashobjc_isMetaClass(const void* classPtr);

/** Check if a class is a root class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return true if the class is a root class.
 */
bool sentrycrashobjc_isRootClass(const void* classPtr);

/** Get the name of a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return the name, or NULL if the name inaccessible.
 */
const char* sentrycrashobjc_className(const void* classPtr);

/** Get the name of an object's class.
 * This also handles tagged pointers.
 *
 * @param objectPtr Pointer to a valid object.
 *
 * @return the name, or NULL if the name is inaccessible.
 */
const char* sentrycrashobjc_objectClassName(const void* objectPtr);

/** Check if a class has a specific name.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param className The class name to compare against.
 *
 * @return true if the class has the specified name.
 */
bool sentrycrashobjc_isClassNamed(const void* const classPtr, const char* const className);

/** Check if a class is of the specified type or a subclass thereof.
 * Note: This function is considerably slower than sentrycrashobjc_baseClassName().
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param className The class name to compare against.
 *
 * @return true if the class is of the specified type or a subclass of that type.
 */
bool sentrycrashobjc_isKindOfClass(const void* classPtr, const char* className);

/** Get the number of ivars registered with a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @return The number of ivars.
 */
int sentrycrashobjc_ivarCount(const void* classPtr);

/** Get information about ivars in a class.
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param dstIvars Buffer to hold ivar data.
 *
 * @param ivarsCount The number of ivars the buffer can hold.
 *
 * @return The number of ivars copied.
 */
int sentrycrashobjc_ivarList(const void* classPtr, SentryCrashObjCIvar* dstIvars, int ivarsCount);

/** Get ivar information by name/
 *
 * @param classPtr Pointer to a valid class.
 *
 * @param name The name of the ivar to get information about.
 *
 * @param dst Buffer to hold the result.
 *
 * @return true if the operation was successful.
 */
bool sentrycrashobjc_ivarNamed(const void* const classPtr, const char* name, SentryCrashObjCIvar* dst);

/** Get the value of an ivar in an object.
 *
 * @param objectPtr Pointer to a valid object.
 *
 * @param ivarIndex The index of the ivar to fetch.
 *
 * @param dst Pointer to buffer big enough to contain the data.
 *
 * @return true if the operation was successful.
 */
bool sentrycrashobjc_ivarValue(const void* objectPtr, int ivarIndex, void* dst);

/* Get the payload from a tagged pointer.
 *
 * @param objectPtr Pointer to a valid object.
 *
 * @return the payload value.
 */
uintptr_t sentrycrashobjc_taggedPointerPayload(const void* taggedObjectPtr);

/** Generate a description of an object.
 *
 * For known common object classes it will print extra information.
 * For all other objects, it will print a standard <SomeClass: 0x12345678>
 *
 * For containers, it will only print the first object in the container.
 *
 * buffer will be null terminated unless bufferLength is 0.
 * If the string doesn't fit, it will be truncated.
 *
 * @param object the object to generate a description for.
 *
 * @param buffer The buffer to copy into.
 *
 * @param bufferLength The length of the buffer.
 *
 * @return the number of bytes copied (not including null terminator).
 */
int sentrycrashobjc_getDescription(void* object, char* buffer, int bufferLength);

/** Get the class type of an object.
 * There are a number of common class types that SentryCrashObjC understamds,
 * listed in SentryCrashObjCClassType.
 *
 * @param object The object to query.
 *
 * @return The class type, or SentryCrashObjCClassTypeUnknown if it couldn't be determined.
 */
SentryCrashObjCClassType sentrycrashobjc_objectClassType(const void* object);


//======================================================================
#pragma mark - Object-Specific Queries -
//======================================================================

/** Check if a number was stored as floating point.
 *
 * @param object The number to query.
 * @return true if the number is floating point.
 */
bool sentrycrashobjc_numberIsFloat(const void* object);

/** Get the contents of a number as a floating point value.
 *
 * @param object The number.
 * @return The value.
 */
double sentrycrashobjc_numberAsFloat(const void* object);

/** Get the contents of a number as an integer value.
 * If the number was stored as floating point, it will be
 * truncated as per C's conversion rules.
 *
 * @param object The number.
 * @return The value.
 */
int64_t sentrycrashobjc_numberAsInteger(const void* object);

/** Copy the contents of a date object.
 *
 * @param datePtr The date to copy data from.
 *
 * @return Time interval since Jan 1 2001 00:00:00 GMT.
 */
double sentrycrashobjc_dateContents(const void* datePtr);

/** Copy the contents of a URL object.
 *
 * dst will be null terminated unless maxLength is 0.
 * If the string doesn't fit, it will be truncated.
 *
 * @param nsurl The URL to copy data from.
 *
 * @param dst The destination to copy into.
 *
 * @param maxLength The size of the buffer.
 *
 * @return the number of bytes copied (not including null terminator).
 */
int sentrycrashobjc_copyURLContents(const void* nsurl, char* dst, int maxLength);

/** Get the length of a string in characters.
 *
 * @param stringPtr Pointer to a string.
 *
 * @return The length of the string.
 */
int sentrycrashobjc_stringLength(const void* const stringPtr);

/** Copy the contents of a string object.
 *
 * dst will be null terminated unless maxLength is 0.
 * If the string doesn't fit, it will be truncated.
 *
 * @param string The string to copy data from.
 *
 * @param dst The destination to copy into.
 *
 * @param maxLength The size of the buffer.
 *
 * @return the number of bytes copied (not including null terminator).
 */
int sentrycrashobjc_copyStringContents(const void* string, char* dst, int maxLength);

/** Get an NSArray's count.
 *
 * @param arrayPtr The array to get the count from.
 *
 * @return The array's count.
 */
int sentrycrashobjc_arrayCount(const void* arrayPtr);

/** Get an NSArray's contents.
 *
 * @param arrayPtr The array to get the contents of.
 *
 * @param contents Location to copy the array's contents into.
 *
 * @param count The number of objects to copy.
 *
 * @return The number of items copied.
 */
int sentrycrashobjc_arrayContents(const void* arrayPtr, uintptr_t* contents, int count);


//======================================================================
#pragma mark - Broken/Unimplemented Stuff -
//======================================================================

/** Get the first entry from an NSDictionary.
 *
 * WARNING: This function is broken!
 *
 * @param dict The dictionary to copy from.
 *
 * @param key Location to copy the first key into.
 *
 * @param value Location to copy the first value into.
 *
 * @return true if the operation was successful.
 */
bool sentrycrashobjc_dictionaryFirstEntry(const void* dict, uintptr_t* key, uintptr_t* value);

/** UNIMPLEMENTED
 */
int sentrycrashobjc_dictionaryCount(const void* dict);


#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashObjC_h
