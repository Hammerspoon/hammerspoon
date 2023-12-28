// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashObjC.c
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

#include "SentryCrashObjC.h"
#include "SentryCrashObjCApple.h"

#include "SentryCrashMemory.h"
#include "SentryCrashString.h"

#include "SentryCrashLogger.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED > 70000
#    include <objc/NSObjCRuntime.h>
#else
#    if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32                   \
        || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#    else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#    endif
#endif
#include <CoreFoundation/CFBase.h>
#include <CoreGraphics/CGBase.h>
#include <inttypes.h>
#include <objc/runtime.h>

#define kMaxNameLength 128

//======================================================================
#pragma mark - Macros -
//======================================================================

// Compiler hints for "if" statements
#define likely_if(x) if (__builtin_expect(x, 1))
#define unlikely_if(x) if (__builtin_expect(x, 0))

//======================================================================
#pragma mark - Types -
//======================================================================

typedef enum {
    ClassSubtypeNone = 0,
    ClassSubtypeCFArray,
    ClassSubtypeNSArrayMutable,
    ClassSubtypeNSArrayImmutable,
    ClassSubtypeCFString,
} ClassSubtype;

typedef struct {
    const char *name;
    SentryCrashObjCClassType type;
    ClassSubtype subtype;
    bool isMutable;
    bool (*isValidObject)(const void *object);
    int (*description)(const void *object, char *buffer, int bufferLength);
    const void *class;
} ClassData;

//======================================================================
#pragma mark - Globals -
//======================================================================

// Forward references
static bool objectIsValid(const void *object);
static bool taggedObjectIsValid(const void *object);
static bool stringIsValid(const void *object);
static bool urlIsValid(const void *object);
static bool arrayIsValid(const void *object);
static bool dateIsValid(const void *object);
static bool numberIsValid(const void *object);
static bool taggedDateIsValid(const void *object);
static bool taggedNumberIsValid(const void *object);
static bool taggedStringIsValid(const void *object);

static int objectDescription(const void *object, char *buffer, int bufferLength);
static int taggedObjectDescription(const void *object, char *buffer, int bufferLength);
static int stringDescription(const void *object, char *buffer, int bufferLength);
static int urlDescription(const void *object, char *buffer, int bufferLength);
static int arrayDescription(const void *object, char *buffer, int bufferLength);
static int dateDescription(const void *object, char *buffer, int bufferLength);
static int numberDescription(const void *object, char *buffer, int bufferLength);
static int taggedDateDescription(const void *object, char *buffer, int bufferLength);
static int taggedNumberDescription(const void *object, char *buffer, int bufferLength);
static int taggedStringDescription(const void *object, char *buffer, int bufferLength);

static ClassData g_classData[] = {
    { "__NSCFString", SentryCrashObjCClassTypeString, ClassSubtypeNone, true, stringIsValid,
        stringDescription },
    { "NSCFString", SentryCrashObjCClassTypeString, ClassSubtypeNone, true, stringIsValid,
        stringDescription },
    { "__NSCFConstantString", SentryCrashObjCClassTypeString, ClassSubtypeNone, true, stringIsValid,
        stringDescription },
    { "NSCFConstantString", SentryCrashObjCClassTypeString, ClassSubtypeNone, true, stringIsValid,
        stringDescription },
    { "__NSArray0", SentryCrashObjCClassTypeArray, ClassSubtypeNSArrayImmutable, false,
        arrayIsValid, arrayDescription },
    { "__NSArrayI", SentryCrashObjCClassTypeArray, ClassSubtypeNSArrayImmutable, false,
        arrayIsValid, arrayDescription },
    { "__NSArrayM", SentryCrashObjCClassTypeArray, ClassSubtypeNSArrayMutable, true, arrayIsValid,
        arrayDescription },
    { "__NSCFArray", SentryCrashObjCClassTypeArray, ClassSubtypeCFArray, false, arrayIsValid,
        arrayDescription },
    { "NSCFArray", SentryCrashObjCClassTypeArray, ClassSubtypeCFArray, false, arrayIsValid,
        arrayDescription },
    { "__NSDate", SentryCrashObjCClassTypeDate, ClassSubtypeNone, false, dateIsValid,
        dateDescription },
    { "NSDate", SentryCrashObjCClassTypeDate, ClassSubtypeNone, false, dateIsValid,
        dateDescription },
    { "__NSCFNumber", SentryCrashObjCClassTypeNumber, ClassSubtypeNone, false, numberIsValid,
        numberDescription },
    { "NSCFNumber", SentryCrashObjCClassTypeNumber, ClassSubtypeNone, false, numberIsValid,
        numberDescription },
    { "NSNumber", SentryCrashObjCClassTypeNumber, ClassSubtypeNone, false, numberIsValid,
        numberDescription },
    { "NSURL", SentryCrashObjCClassTypeURL, ClassSubtypeNone, false, urlIsValid, urlDescription },
    { NULL, SentryCrashObjCClassTypeUnknown, ClassSubtypeNone, false, objectIsValid,
        objectDescription },
};

static ClassData g_taggedClassData[] = {
    { "NSAtom", SentryCrashObjCClassTypeUnknown, ClassSubtypeNone, false, taggedObjectIsValid,
        taggedObjectDescription },
    { NULL, SentryCrashObjCClassTypeUnknown, ClassSubtypeNone, false, taggedObjectIsValid,
        taggedObjectDescription },
    { "NSString", SentryCrashObjCClassTypeString, ClassSubtypeNone, false, taggedStringIsValid,
        taggedStringDescription },
    { "NSNumber", SentryCrashObjCClassTypeNumber, ClassSubtypeNone, false, taggedNumberIsValid,
        taggedNumberDescription },
    { "NSIndexPath", SentryCrashObjCClassTypeUnknown, ClassSubtypeNone, false, taggedObjectIsValid,
        taggedObjectDescription },
    { "NSManagedObjectID", SentryCrashObjCClassTypeUnknown, ClassSubtypeNone, false,
        taggedObjectIsValid, taggedObjectDescription },
    { "NSDate", SentryCrashObjCClassTypeDate, ClassSubtypeNone, false, taggedDateIsValid,
        taggedDateDescription },
    { NULL, SentryCrashObjCClassTypeUnknown, ClassSubtypeNone, false, taggedObjectIsValid,
        taggedObjectDescription },
};
static int g_taggedClassDataCount = sizeof(g_taggedClassData) / sizeof(*g_taggedClassData);

static const char *g_blockBaseClassName = "NSBlock";

//======================================================================
#pragma mark - Utility -
//======================================================================

#if SUPPORT_TAGGED_POINTERS
static bool
isTaggedPointer(const void *pointer)
{
    return (((uintptr_t)pointer) & TAG_MASK) != 0;
}
static int
getTaggedSlot(const void *pointer)
{
    return (int)((((uintptr_t)pointer) >> TAG_SLOT_SHIFT) & TAG_SLOT_MASK);
}
static uintptr_t
getTaggedPayload(const void *pointer)
{
    return (((uintptr_t)pointer) << TAG_PAYLOAD_LSHIFT) >> TAG_PAYLOAD_RSHIFT;
}
#else
static bool
isTaggedPointer(__unused const void *pointer)
{
    return false;
}
static int
getTaggedSlot(__unused const void *pointer)
{
    return 0;
}
static uintptr_t
getTaggedPayload(const void *pointer)
{
    return (uintptr_t)pointer;
}
#endif

/** Get class data for a tagged pointer.
 *
 * @param object The tagged pointer.
 * @return The class data.
 */
static const ClassData *
getClassDataFromTaggedPointer(const void *const object)
{
    int slot = getTaggedSlot(object);
    return &g_taggedClassData[slot];
}

static bool
isValidTaggedPointer(const void *object)
{
    if (isTaggedPointer(object)) {
        if (getTaggedSlot(object) <= g_taggedClassDataCount) {
            const ClassData *classData = getClassDataFromTaggedPointer(object);
            return classData->type != SentryCrashObjCClassTypeUnknown;
        }
    }
    return false;
}

static const struct class_t *
decodeIsaPointer(const void *const isaPointer)
{
#if ISA_TAG_MASK
    uintptr_t isa = (uintptr_t)isaPointer;
    if (isa & ISA_TAG_MASK) {
#    if TARGET_OS_IOS && defined(__arm64__)
        if (floor(kCFCoreFoundationVersionNumber) <= kCFCoreFoundationVersionNumber_iOS_8_x_Max) {
            return (const struct class_t *)(isa & ISA_MASK_OLD);
        }
        return (const struct class_t *)(isa & ISA_MASK);
#    else
        return (const struct class_t *)(isa & ISA_MASK);
#    endif
    }
#endif
    return (const struct class_t *)isaPointer;
}

static const void *
getIsaPointer(const void *const objectOrClassPtr)
{
    // This is wrong. Should not get class data here.
    //    if(sentrycrashobjc_isTaggedPointer(objectOrClassPtr))
    //    {
    //        return getClassDataFromTaggedPointer(objectOrClassPtr)->class;
    //    }

    const struct class_t *ptr = objectOrClassPtr;
    return decodeIsaPointer(ptr->isa);
}

static inline struct class_rw_t *
getClassRW(const struct class_t *const class)
{
    uintptr_t ptr = class->data_NEVER_USE & FAST_DATA_MASK;
    return (struct class_rw_t *)ptr;
}

static inline const struct class_ro_t *
getClassRO(const struct class_t *const class)
{
    class_rw_t *rw = getClassRW(class);
    uintptr_t ext_ptr = rw->ro_or_rw_ext;
    /* When objc_class_abi_version >= 1, it's a tagged union based on the low bit:
     * 0: class_ro_t  1: class_rw_ext_t
     * @see https://opensource.apple.com/source/objc4/objc4-781/runtime/objc-runtime-new.h */
    if (ext_ptr & 0x1UL) {
        ext_ptr &= ~0x1UL;
        struct class_rw_ext_t *rw_ext = (struct class_rw_ext_t *)ext_ptr;
        return rw_ext->ro;
    } else {
        struct class_ro_t *ro = (struct class_ro_t *)ext_ptr;
        return ro;
    }
}

static inline const void *
getSuperClass(const void *const classPtr)
{
    const struct class_t *class = classPtr;
    return class->superclass;
}

static inline bool
isMetaClass(const void *const classPtr)
{
    return (getClassRO(classPtr)->flags & RO_META) != 0;
}

static inline bool
isRootClass(const void *const classPtr)
{
    return (getClassRO(classPtr)->flags & RO_ROOT) != 0;
}

static inline const char *
getClassName(const void *classPtr)
{
    const struct class_ro_t *ro = getClassRO(classPtr);
    return ro->name;
}

/** Check if a tagged pointer is a number.
 *
 * @param object The object to query.
 * @return true if the tagged pointer is an NSNumber.
 */
static bool
isTaggedPointerNSNumber(const void *const object)
{
    return getTaggedSlot(object) == OBJC_TAG_NSNumber;
}

/** Check if a tagged pointer is a string.
 *
 * @param object The object to query.
 * @return true if the tagged pointer is an NSString.
 */
static bool
isTaggedPointerNSString(const void *const object)
{
    return getTaggedSlot(object) == OBJC_TAG_NSString;
}

/** Check if a tagged pointer is a date.
 *
 * @param object The object to query.
 * @return true if the tagged pointer is an NSDate.
 */
static bool
isTaggedPointerNSDate(const void *const object)
{
    return getTaggedSlot(object) == OBJC_TAG_NSDate;
}

/** Extract an integer from a tagged NSNumber.
 *
 * @param object The NSNumber object (must be a tagged pointer).
 * @return The integer value.
 */
static int64_t
extractTaggedNSNumber(const void *const object)
{
    intptr_t signedPointer = (intptr_t)object;
#if SUPPORT_TAGGED_POINTERS
    intptr_t value = (signedPointer << TAG_PAYLOAD_LSHIFT) >> TAG_PAYLOAD_RSHIFT;
#else
    intptr_t value = signedPointer & 0;
#endif

    // The lower 4 bits encode type information so shift them out.
    return (int64_t)(value >> 4);
}

static int
getTaggedNSStringLength(const void *const object)
{
    uintptr_t payload = getTaggedPayload(object);
    return (int)(payload & 0xf);
}

static int
extractTaggedNSString(const void *const object, char *buffer, int bufferLength)
{
    int length = getTaggedNSStringLength(object);
    int copyLength = ((length + 1) > bufferLength) ? (bufferLength - 1) : length;
    uintptr_t payload = getTaggedPayload(object);
    uintptr_t value = payload >> 4;
    static char *alphabet = "eilotrm.apdnsIc ufkMShjTRxgC4013bDNvwyUL2O856P-B79AFKEWV_zGJ/HYX";
    if (length <= 7) {
        for (int i = 0; i < copyLength; i++) {
            // ASCII case, limit to bottom 7 bits just in case
            buffer[i] = (char)(value & 0x7f);
            value >>= 8;
        }
    } else if (length <= 9) {
        for (int i = 0; i < copyLength; i++) {
            uintptr_t index = (value >> ((length - 1 - i) * 6)) & 0x3f;
            buffer[i] = alphabet[index];
        }
    } else if (length <= 11) {
        for (int i = 0; i < copyLength; i++) {
            uintptr_t index = (value >> ((length - 1 - i) * 5)) & 0x1f;
            buffer[i] = alphabet[index];
        }
    } else {
        buffer[0] = 0;
    }
    buffer[length] = 0;

    return length;
}

/** Extract a tagged NSDate's time value as an absolute time.
 *
 * @param object The NSDate object (must be a tagged pointer).
 * @return The date's absolute time.
 */
static CFAbsoluteTime
extractTaggedNSDate(const void *const object)
{
    uintptr_t payload = getTaggedPayload(object);
    // Payload is a 60-bit float. Fortunately we can just cast across from
    // an integer pointer after shifting out the upper 4 bits.
    payload <<= 4;
    CFAbsoluteTime value = *((CFAbsoluteTime *)&payload);
    return value;
}

/** Get any special class metadata we have about the specified class.
 * It will return a generic metadata object if the type is not recognized.
 *
 * Note: The Objective-C runtime is free to change a class address,
 * so I can't just blindly store class pointers at application start
 * and then compare against them later. However, comparing strings is
 * slow, so I've reached a compromise. Since I'm omly using this at
 * crash time, I can assume that the Objective-C environment is frozen.
 * As such, I can keep a cache of discovered classes. If, however, this
 * library is used outside of a frozen environment, caching will be
 * unreliable.
 *
 * @param class The class to examine.
 *
 * @return The associated class data.
 */
static ClassData *
getClassData(const void *class)
{
    const char *className = getClassName(class);
    for (ClassData *data = g_classData;; data++) {
        unlikely_if(data->name == NULL) { return data; }
        unlikely_if(class == data->class) { return data; }
        unlikely_if(data->class == NULL && strcmp(className, data->name) == 0)
        {
            data->class = class;
            return data;
        }
    }
}

static inline const ClassData *
getClassDataFromObject(const void *object)
{
    if (isTaggedPointer(object)) {
        return getClassDataFromTaggedPointer(object);
    }
    const struct class_t *obj = object;
    return getClassData(getIsaPointer(obj));
}

static int
stringPrintf(char *buffer, int bufferLength, const char *fmt, ...)
{
    unlikely_if(bufferLength == 0) { return 0; }

    va_list args;
    va_start(args, fmt);
    int printLength = vsnprintf(buffer, bufferLength, fmt, args);
    va_end(args);

    unlikely_if(printLength < 0)
    {
        *buffer = 0;
        return 0;
    }
    unlikely_if(printLength > bufferLength) { return bufferLength - 1; }
    return printLength;
}

//======================================================================
#pragma mark - Validation -
//======================================================================

// Lookup table for validating class/ivar names and objc @encode types.
// An ivar name must start with a letter, and can contain letters & numbers.
// An ivar type can in theory be any combination of numbers, letters, and
// symbols in the ASCII range (0x21-0x7e).
#define INV 0 // Invalid.
#define N_C 5 // Name character: Valid for anything except the first letter of a name.
#define N_S 7 // Name start character: Valid for anything.
#define T_C 4 // Type character: Valid for types only.

static const unsigned int g_nameChars[] = {
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    N_C,
    N_C,
    N_C,
    N_C,
    N_C,
    N_C,
    N_C,
    N_C,
    N_C,
    N_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    T_C,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    T_C,
    T_C,
    T_C,
    T_C,
    N_S,
    T_C,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    N_S,
    T_C,
    T_C,
    T_C,
    T_C,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
};

#define VALID_NAME_CHAR(A) ((g_nameChars[(uint8_t)(A)] & 1) != 0)
#define VALID_NAME_START_CHAR(A) ((g_nameChars[(uint8_t)(A)] & 2) != 0)
#define VALID_TYPE_CHAR(A) ((g_nameChars[(uint8_t)(A)] & 7) != 0)

static bool
isValidName(const char *const name, const int maxLength)
{
    if ((uintptr_t)name + (unsigned)maxLength < (uintptr_t)name) {
        // Wrapped around address space.
        return false;
    }

    char buffer[maxLength];
    int length = sentrycrashmem_copyMaxPossible(name, buffer, maxLength);
    if (length == 0 || !VALID_NAME_START_CHAR(name[0])) {
        return false;
    }
    for (int i = 1; i < length; i++) {
        unlikely_if(!VALID_NAME_CHAR(name[i]))
        {
            if (name[i] == 0) {
                return true;
            }
            return false;
        }
    }
    return false;
}

static bool
isValidIvarType(const char *const type)
{
    char buffer[100];
    const int maxLength = sizeof(buffer);

    if ((uintptr_t)type + maxLength < (uintptr_t)type) {
        // Wrapped around address space.
        return false;
    }

    int length = sentrycrashmem_copyMaxPossible(type, buffer, maxLength);
    if (length == 0 || !VALID_TYPE_CHAR(type[0])) {
        return false;
    }
    for (int i = 0; i < length; i++) {
        unlikely_if(!VALID_TYPE_CHAR(type[i]))
        {
            if (type[i] == 0) {
                return true;
            }
        }
    }
    return false;
}

static bool
containsValidExtData(class_rw_t *rw)
{
    uintptr_t ext_ptr = rw->ro_or_rw_ext;
    if (ext_ptr & 0x1UL) {
        ext_ptr &= ~0x1UL;
        struct class_rw_ext_t *rw_ext = (struct class_rw_ext_t *)ext_ptr;
        if (!sentrycrashmem_isMemoryReadable(rw_ext, sizeof(*rw_ext))) {
            return false;
        }
    }

    return true;
}

static bool
containsValidROData(const void *const classPtr)
{
    const struct class_t *const class = classPtr;
    if (!sentrycrashmem_isMemoryReadable(class, sizeof(*class))) {
        return false;
    }
    class_rw_t *rw = getClassRW(class);
    if (!sentrycrashmem_isMemoryReadable(rw, sizeof(*rw))) {
        return false;
    }
    if (!containsValidExtData(rw)) {
        return false;
    }
    const class_ro_t *ro = getClassRO(class);
    if (!sentrycrashmem_isMemoryReadable(ro, sizeof(*ro))) {
        return false;
    }
    return true;
}

static bool
containsValidIvarData(const void *const classPtr)
{
    const struct class_ro_t *ro = getClassRO(classPtr);
    const struct ivar_list_t *ivars = ro->ivars;
    if (ivars == NULL) {
        return true;
    }
    if (!sentrycrashmem_isMemoryReadable(ivars, sizeof(*ivars))) {
        return false;
    }

    if (ivars->count > 0) {
        struct ivar_t ivar;
        uint8_t *ivarPtr = (uint8_t *)(&ivars->first) + ivars->entsizeAndFlags;
        for (uint32_t i = 1; i < ivars->count; i++) {
            if (!sentrycrashmem_copySafely(ivarPtr, &ivar, sizeof(ivar))) {
                return false;
            }
            if (!sentrycrashmem_isMemoryReadable(ivarPtr, (int)ivars->entsizeAndFlags)) {
                return false;
            }
            if (!sentrycrashmem_isMemoryReadable(ivar.offset, sizeof(*ivar.offset))) {
                return false;
            }
            if (!isValidName(ivar.name, kMaxNameLength)) {
                return false;
            }
            if (!isValidIvarType(ivar.type)) {
                return false;
            }
            ivarPtr += ivars->entsizeAndFlags;
        }
    }
    return true;
}

static bool
containsValidClassName(const void *const classPtr)
{
    const struct class_ro_t *ro = getClassRO(classPtr);
    return isValidName(ro->name, kMaxNameLength);
}

static bool
hasValidIsaPointer(const void *object)
{
    const struct class_t *isaPtr = getIsaPointer(object);
    return sentrycrashmem_isMemoryReadable(isaPtr, sizeof(*isaPtr));
}

static inline bool
isValidClass(const void *classPtr)
{
    const class_t *class = classPtr;
    if (!sentrycrashmem_isMemoryReadable(class, sizeof(*class))) {
        return false;
    }
    if (!containsValidROData(class)) {
        return false;
    }
    if (!containsValidClassName(class)) {
        return false;
    }
    if (!containsValidIvarData(class)) {
        return false;
    }
    return true;
}

static inline bool
isValidObject(const void *objectPtr)
{
    if (isTaggedPointer(objectPtr)) {
        return isValidTaggedPointer(objectPtr);
    }
    const class_t *object = objectPtr;
    if (!sentrycrashmem_isMemoryReadable(object, sizeof(*object))) {
        return false;
    }
    if (!hasValidIsaPointer(object)) {
        return false;
    }
    if (!isValidClass(getIsaPointer(object))) {
        return false;
    }
    return true;
}

//======================================================================
#pragma mark - Basic Objective-C Queries -
//======================================================================

const void *
sentrycrashobjc_isaPointer(const void *const objectOrClassPtr)
{
    return getIsaPointer(objectOrClassPtr);
}

const void *
sentrycrashobjc_superClass(const void *const classPtr)
{
    return getSuperClass(classPtr);
}

bool
sentrycrashobjc_isMetaClass(const void *const classPtr)
{
    return isMetaClass(classPtr);
}

bool
sentrycrashobjc_isRootClass(const void *const classPtr)
{
    return isRootClass(classPtr);
}

const char *
sentrycrashobjc_className(const void *classPtr)
{
    return getClassName(classPtr);
}

const char *
sentrycrashobjc_objectClassName(const void *objectPtr)
{
    if (isTaggedPointer(objectPtr)) {
        if (isValidTaggedPointer(objectPtr)) {
            const ClassData *class = getClassDataFromTaggedPointer(objectPtr);
            return class->name;
        }
        return NULL;
    }
    const void *isaPtr = getIsaPointer(objectPtr);
    return getClassName(isaPtr);
}

bool
sentrycrashobjc_isClassNamed(const void *const classPtr, const char *const className)
{
    const char *name = getClassName(classPtr);
    if (name == NULL || className == NULL) {
        return false;
    }
    return strcmp(name, className) == 0;
}

bool
sentrycrashobjc_isKindOfClass(const void *const classPtr, const char *const className)
{
    if (className == NULL) {
        return false;
    }

    const struct class_t *class = (const struct class_t *)classPtr;

    for (int i = 0; i < 20; i++) {
        const char *name = getClassName(class);
        if (name == NULL) {
            return false;
        }
        if (strcmp(className, name) == 0) {
            return true;
        }
        class = class->superclass;
        if (!containsValidROData(class)) {
            return false;
        }
    }
    return false;
}

const void *
sentrycrashobjc_baseClass(const void *const classPtr)
{
    const struct class_t *superClass = classPtr;
    const struct class_t *subClass = classPtr;

    for (int i = 0; i < 20; i++) {
        if (isRootClass(superClass)) {
            return subClass;
        }
        subClass = superClass;
        superClass = superClass->superclass;
        if (!containsValidROData(superClass)) {
            return NULL;
        }
    }
    return NULL;
}

int
sentrycrashobjc_ivarCount(const void *const classPtr)
{
    const struct ivar_list_t *ivars = getClassRO(classPtr)->ivars;
    if (ivars == NULL) {
        return 0;
    }
    return (int)ivars->count;
}

int
sentrycrashobjc_ivarList(const void *const classPtr, SentryCrashObjCIvar *dstIvars, int ivarsCount)
{
    // TODO: Check this for a possible bad access.
    if (dstIvars == NULL) {
        return 0;
    }

    int count = sentrycrashobjc_ivarCount(classPtr);
    if (count == 0) {
        return 0;
    }

    if (ivarsCount < count) {
        count = ivarsCount;
    }
    const struct ivar_list_t *srcIvars = getClassRO(classPtr)->ivars;
    uintptr_t srcPtr = (uintptr_t)&srcIvars->first;
    const struct ivar_t *src = (void *)srcPtr;
    for (int i = 0; i < count; i++) {
        SentryCrashObjCIvar *dst = &dstIvars[i];
        dst->name = src->name;
        dst->type = src->type;
        dst->index = i;
        srcPtr += srcIvars->entsizeAndFlags;
        src = (void *)srcPtr;
    }
    return count;
}

bool
sentrycrashobjc_ivarNamed(const void *const classPtr, const char *name, SentryCrashObjCIvar *dst)
{
    if (name == NULL) {
        return false;
    }
    const struct ivar_list_t *ivars = getClassRO(classPtr)->ivars;
    uintptr_t ivarPtr = (uintptr_t)&ivars->first;
    const struct ivar_t *ivar = (void *)ivarPtr;
    // For unknown reasons sometimes ivars is null and tests become flakey
    if (ivars == NULL) {
        return false;
    }
    for (int i = 0; i < (int)ivars->count; i++) {
        if (ivar->name != NULL && strcmp(name, ivar->name) == 0) {
            dst->name = ivar->name;
            dst->type = ivar->type;
            dst->index = i;
            return true;
        }
        ivarPtr += ivars->entsizeAndFlags;
        ivar = (void *)ivarPtr;
    }
    return false;
}

bool
sentrycrashobjc_ivarValue(const void *const objectPtr, int ivarIndex, void *dst)
{
    if (isTaggedPointer(objectPtr)) {
        // Naively assume they want "value".
        if (isTaggedPointerNSDate(objectPtr)) {
            CFTimeInterval value = extractTaggedNSDate(objectPtr);
            memcpy(dst, &value, sizeof(value));
            return true;
        }
        if (isTaggedPointerNSNumber(objectPtr)) {
            // TODO: Correct to assume 64-bit signed int? What does the actual
            // ivar say?
            int64_t value = extractTaggedNSNumber(objectPtr);
            memcpy(dst, &value, sizeof(value));
            return true;
        }
        return false;
    }

    const void *const classPtr = getIsaPointer(objectPtr);
    const struct ivar_list_t *ivars = getClassRO(classPtr)->ivars;
    if (ivarIndex >= (int)ivars->count) {
        return false;
    }
    uintptr_t ivarPtr = (uintptr_t)&ivars->first;
    const struct ivar_t *ivar
        = (void *)(ivarPtr + (uintptr_t)ivars->entsizeAndFlags * (uintptr_t)ivarIndex);

    uintptr_t valuePtr = (uintptr_t)objectPtr + (uintptr_t)*ivar->offset;
    if (!sentrycrashmem_copySafely((void *)valuePtr, dst, (int)ivar->size)) {
        return false;
    }
    return true;
}

uintptr_t
sentrycrashobjc_taggedPointerPayload(const void *taggedObjectPtr)
{
    return getTaggedPayload(taggedObjectPtr);
}

static inline bool
isBlockClass(const void *class)
{
    const void *baseClass = sentrycrashobjc_baseClass(class);
    if (baseClass == NULL) {
        return false;
    }
    const char *name = getClassName(baseClass);
    if (name == NULL) {
        return false;
    }
    return strcmp(name, g_blockBaseClassName) == 0;
}

SentryCrashObjCType
sentrycrashobjc_objectType(const void *objectOrClassPtr)
{
    if (objectOrClassPtr == NULL) {
        return SentryCrashObjCTypeUnknown;
    }

    if (isTaggedPointer(objectOrClassPtr)) {
        return SentryCrashObjCTypeObject;
    }

    if (!isValidObject(objectOrClassPtr)) {
        return SentryCrashObjCTypeUnknown;
    }

    if (!isValidClass(objectOrClassPtr)) {
        return SentryCrashObjCTypeUnknown;
    }

    const struct class_t *isa = getIsaPointer(objectOrClassPtr);

    if (isBlockClass(isa)) {
        return SentryCrashObjCTypeBlock;
    }
    if (!isMetaClass(isa)) {
        return SentryCrashObjCTypeObject;
    }

    return SentryCrashObjCTypeClass;
}

//======================================================================
#pragma mark - Unknown Object -
//======================================================================

static bool
objectIsValid(__unused const void *object)
{
    // If it passed sentrycrashobjc_objectType, it's been validated as much as
    // possible.
    return true;
}

static bool
taggedObjectIsValid(const void *object)
{
    return isValidTaggedPointer(object);
}

static int
objectDescription(const void *object, char *buffer, int bufferLength)
{
    const void *class = getIsaPointer(object);
    const char *name = getClassName(class);
    uintptr_t objPointer = (uintptr_t)object;
    const char *fmt = sizeof(uintptr_t) == sizeof(uint32_t) ? "<%s: 0x%08x>" : "<%s: 0x%016x>";
    return stringPrintf(buffer, bufferLength, fmt, name, objPointer);
}

static int
taggedObjectDescription(const void *object, char *buffer, int bufferLength)
{
    const ClassData *data = getClassDataFromTaggedPointer(object);
    const char *name = data->name;
    uintptr_t objPointer = (uintptr_t)object;
    const char *fmt = sizeof(uintptr_t) == sizeof(uint32_t) ? "<%s: 0x%08x>" : "<%s: 0x%016x>";
    return stringPrintf(buffer, bufferLength, fmt, name, objPointer);
}

//======================================================================
#pragma mark - NSString -
//======================================================================

static inline const char *
stringStart(const struct __CFString *str)
{
    return (const char *)__CFStrContents(str) + (__CFStrHasLengthByte(str) ? 1 : 0);
}

static bool
stringIsValid(const void *const stringPtr)
{
    const struct __CFString *string = stringPtr;
    struct __CFString temp;
    uint8_t oneByte;
    CFIndex length = -1;
    if (!sentrycrashmem_copySafely(string, &temp, sizeof(string->base))) {
        return false;
    }

    if (__CFStrIsInline(string)) {
        if (!sentrycrashmem_copySafely(
                &string->variants.inline1, &temp, sizeof(string->variants.inline1))) {
            return false;
        }
        length = string->variants.inline1.length;
    } else if (__CFStrIsMutable(string)) {
        if (!sentrycrashmem_copySafely(&string->variants.notInlineMutable, &temp,
                sizeof(string->variants.notInlineMutable))) {
            return false;
        }
        length = string->variants.notInlineMutable.length;
    } else if (!__CFStrHasLengthByte(string)) {
        if (!sentrycrashmem_copySafely(&string->variants.notInlineImmutable1, &temp,
                sizeof(string->variants.notInlineImmutable1))) {
            return false;
        }
        length = string->variants.notInlineImmutable1.length;
    } else {
        if (!sentrycrashmem_copySafely(&string->variants.notInlineImmutable2, &temp,
                sizeof(string->variants.notInlineImmutable2))) {
            return false;
        }
        if (!sentrycrashmem_copySafely(__CFStrContents(string), &oneByte, sizeof(oneByte))) {
            return false;
        }
        length = oneByte;
    }

    if (length < 0) {
        return false;
    } else if (length > 0) {
        if (!sentrycrashmem_copySafely(stringStart(string), &oneByte, sizeof(oneByte))) {
            return false;
        }
    }
    return true;
}

int
sentrycrashobjc_stringLength(const void *const stringPtr)
{
    if (isTaggedPointer(stringPtr) && isTaggedPointerNSString(stringPtr)) {
        return getTaggedNSStringLength(stringPtr);
    }

    const struct __CFString *string = stringPtr;

    if (__CFStrHasExplicitLength(string)) {
        if (__CFStrIsInline(string)) {
            return (int)string->variants.inline1.length;
        } else {
            return (int)string->variants.notInlineImmutable1.length;
        }
    } else {
        return *((uint8_t *)__CFStrContents(string));
    }
}

#define kUTF16_LeadSurrogateStart 0xd800u
#define kUTF16_LeadSurrogateEnd 0xdbffu
#define kUTF16_TailSurrogateStart 0xdc00u
#define kUTF16_TailSurrogateEnd 0xdfffu
#define kUTF16_FirstSupplementaryPlane 0x10000u

static int
copyAndConvertUTF16StringToUTF8(
    const void *const src, void *const dst, int charCount, int maxByteCount)
{
    const uint16_t *pSrc = src;
    uint8_t *pDst = dst;
    const uint8_t *const pDstEnd = pDst + maxByteCount - 1; // Leave room for null termination.
    for (int charsRemaining = charCount; charsRemaining > 0 && pDst < pDstEnd; charsRemaining--) {
        // Decode UTF-16
        uint32_t character = 0;
        uint16_t leadSurrogate = *pSrc++;
        likely_if(
            leadSurrogate < kUTF16_LeadSurrogateStart || leadSurrogate > kUTF16_TailSurrogateEnd)
        {
            character = leadSurrogate;
        }
        else if (leadSurrogate > kUTF16_LeadSurrogateEnd)
        {
            // Inverted surrogate
            *((uint8_t *)dst) = 0;
            return 0;
        }
        else
        {
            uint16_t tailSurrogate = *pSrc++;
            if (tailSurrogate < kUTF16_TailSurrogateStart
                || tailSurrogate > kUTF16_TailSurrogateEnd) {
                // Invalid tail surrogate
                *((uint8_t *)dst) = 0;
                return 0;
            }
            character = ((leadSurrogate - kUTF16_LeadSurrogateStart) << 10)
                + (tailSurrogate - kUTF16_TailSurrogateStart);
            character += kUTF16_FirstSupplementaryPlane;
            charsRemaining--;
        }

        // Encode UTF-8
        likely_if(character <= 0x7f) { *pDst++ = (uint8_t)character; }
        else if (character <= 0x7ff)
        {
            if (pDstEnd - pDst >= 2) {
                *pDst++ = (uint8_t)(0xc0 | (character >> 6));
                *pDst++ = (uint8_t)(0x80 | (character & 0x3f));
            } else {
                break;
            }
        }
        else if (character <= 0xffff)
        {
            if (pDstEnd - pDst >= 3) {
                *pDst++ = (uint8_t)(0xe0 | (character >> 12));
                *pDst++ = (uint8_t)(0x80 | ((character >> 6) & 0x3f));
                *pDst++ = (uint8_t)(0x80 | (character & 0x3f));
            } else {
                break;
            }
        }
        // RFC3629 restricts UTF-8 to end at 0x10ffff.
        else if (character <= 0x10ffff)
        {
            if (pDstEnd - pDst >= 4) {
                *pDst++ = (uint8_t)(0xf0 | (character >> 18));
                *pDst++ = (uint8_t)(0x80 | ((character >> 12) & 0x3f));
                *pDst++ = (uint8_t)(0x80 | ((character >> 6) & 0x3f));
                *pDst++ = (uint8_t)(0x80 | (character & 0x3f));
            } else {
                break;
            }
        }
        else
        {
            // Invalid unicode.
            *((uint8_t *)dst) = 0;
            return 0;
        }
    }

    // Null terminate and return.
    *pDst = 0;
    return (int)(pDst - (uint8_t *)dst);
}

static int
copy8BitString(const void *const src, void *const dst, int charCount, int maxByteCount)
{
    unlikely_if(maxByteCount == 0) { return 0; }
    unlikely_if(charCount == 0)
    {
        *((uint8_t *)dst) = 0;
        return 0;
    }

    unlikely_if(charCount >= maxByteCount) { charCount = maxByteCount - 1; }
    unlikely_if(!sentrycrashmem_copySafely(src, dst, charCount))
    {
        *((uint8_t *)dst) = 0;
        return 0;
    }
    uint8_t *charDst = dst;
    charDst[charCount] = 0;
    return charCount;
}

int
sentrycrashobjc_copyStringContents(const void *stringPtr, char *dst, int maxByteCount)
{
    if (isTaggedPointer(stringPtr) && isTaggedPointerNSString(stringPtr)) {
        return extractTaggedNSString(stringPtr, dst, maxByteCount);
    }
    const struct __CFString *string = stringPtr;
    int charCount = sentrycrashobjc_stringLength(string);

    const char *src = stringStart(string);
    if (__CFStrIsUnicode(string)) {
        return copyAndConvertUTF16StringToUTF8(src, dst, charCount, maxByteCount);
    }

    return copy8BitString(src, dst, charCount, maxByteCount);
}

static int
stringDescription(const void *object, char *buffer, int bufferLength)
{
    char *pBuffer = buffer;
    char *pEnd = buffer + bufferLength;

    pBuffer += objectDescription(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": \"");
    pBuffer += sentrycrashobjc_copyStringContents(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), "\"");

    return (int)(pBuffer - buffer);
}

static bool
taggedStringIsValid(const void *const object)
{
    return isValidTaggedPointer(object) && isTaggedPointerNSString(object);
}

static int
taggedStringDescription(const void *object, char *buffer, __unused int bufferLength)
{
    return extractTaggedNSString(object, buffer, bufferLength);
}

//======================================================================
#pragma mark - NSURL -
//======================================================================

static bool
urlIsValid(const void *const urlPtr)
{
    struct __CFURL url;
    if (!sentrycrashmem_copySafely(urlPtr, &url, sizeof(url))) {
        return false;
    }
    return stringIsValid(url._string);
}

int
sentrycrashobjc_copyURLContents(const void *const urlPtr, char *dst, int maxLength)
{
    const struct __CFURL *url = urlPtr;
    return sentrycrashobjc_copyStringContents(url->_string, dst, maxLength);
}

static int
urlDescription(const void *object, char *buffer, int bufferLength)
{
    char *pBuffer = buffer;
    char *pEnd = buffer + bufferLength;

    pBuffer += objectDescription(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": \"");
    pBuffer += sentrycrashobjc_copyURLContents(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), "\"");

    return (int)(pBuffer - buffer);
}

//======================================================================
#pragma mark - NSDate -
//======================================================================

static bool
dateIsValid(const void *const datePtr)
{
    struct __CFDate temp;
    return sentrycrashmem_copySafely(datePtr, &temp, sizeof(temp));
}

CFAbsoluteTime
sentrycrashobjc_dateContents(const void *const datePtr)
{
    if (isValidTaggedPointer(datePtr)) {
        return extractTaggedNSDate(datePtr);
    }
    const struct __CFDate *date = datePtr;
    return date->_time;
}

static int
dateDescription(const void *object, char *buffer, int bufferLength)
{
    char *pBuffer = buffer;
    char *pEnd = buffer + bufferLength;

    CFAbsoluteTime time = sentrycrashobjc_dateContents(object);
    pBuffer += objectDescription(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": %f", time);

    return (int)(pBuffer - buffer);
}

static bool
taggedDateIsValid(const void *const datePtr)
{
    return isValidTaggedPointer(datePtr) && isTaggedPointerNSDate(datePtr);
}

static int
taggedDateDescription(const void *object, char *buffer, int bufferLength)
{
    char *pBuffer = buffer;
    char *pEnd = buffer + bufferLength;

    CFAbsoluteTime time = extractTaggedNSDate(object);
    pBuffer += taggedObjectDescription(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": %f", time);

    return (int)(pBuffer - buffer);
}

//======================================================================
#pragma mark - NSNumber -
//======================================================================

#define NSNUMBER_CASE(CFTYPE, RETURN_TYPE, CAST_TYPE, DATA)                                        \
    case CFTYPE: {                                                                                 \
        RETURN_TYPE result;                                                                        \
        memcpy(&result, DATA, sizeof(result));                                                     \
        return (CAST_TYPE)result;                                                                  \
    }

#define EXTRACT_AND_RETURN_NSNUMBER(OBJECT, RETURN_TYPE)                                           \
    if (isValidTaggedPointer(object)) {                                                            \
        return extractTaggedNSNumber(object);                                                      \
    }                                                                                              \
    const struct __CFNumber *number = OBJECT;                                                      \
    CFNumberType cftype = CFNumberGetType((CFNumberRef)OBJECT);                                    \
    const void *data = &(number->_pad);                                                            \
    switch (cftype) {                                                                              \
        NSNUMBER_CASE(kCFNumberSInt8Type, int8_t, RETURN_TYPE, data)                               \
        NSNUMBER_CASE(kCFNumberSInt16Type, int16_t, RETURN_TYPE, data)                             \
        NSNUMBER_CASE(kCFNumberSInt32Type, int32_t, RETURN_TYPE, data)                             \
        NSNUMBER_CASE(kCFNumberSInt64Type, int64_t, RETURN_TYPE, data)                             \
        NSNUMBER_CASE(kCFNumberFloat32Type, Float32, RETURN_TYPE, data)                            \
        NSNUMBER_CASE(kCFNumberFloat64Type, Float64, RETURN_TYPE, data)                            \
        NSNUMBER_CASE(kCFNumberCharType, char, RETURN_TYPE, data)                                  \
        NSNUMBER_CASE(kCFNumberShortType, short, RETURN_TYPE, data)                                \
        NSNUMBER_CASE(kCFNumberIntType, int, RETURN_TYPE, data)                                    \
        NSNUMBER_CASE(kCFNumberLongType, long, RETURN_TYPE, data)                                  \
        NSNUMBER_CASE(kCFNumberLongLongType, long long, RETURN_TYPE, data)                         \
        NSNUMBER_CASE(kCFNumberFloatType, float, RETURN_TYPE, data)                                \
        NSNUMBER_CASE(kCFNumberDoubleType, double, RETURN_TYPE, data)                              \
        NSNUMBER_CASE(kCFNumberCFIndexType, CFIndex, RETURN_TYPE, data)                            \
        NSNUMBER_CASE(kCFNumberNSIntegerType, NSInteger, RETURN_TYPE, data)                        \
        NSNUMBER_CASE(kCFNumberCGFloatType, CGFloat, RETURN_TYPE, data)                            \
    }

Float64
sentrycrashobjc_numberAsFloat(const void *object)
{
    EXTRACT_AND_RETURN_NSNUMBER(object, Float64);
    return NAN;
}

int64_t
sentrycrashobjc_numberAsInteger(const void *object)
{
    EXTRACT_AND_RETURN_NSNUMBER(object, int64_t);
    return 0;
}

bool
sentrycrashobjc_numberIsFloat(const void *object)
{
    return CFNumberIsFloatType((CFNumberRef)object);
}

static bool
numberIsValid(const void *const datePtr)
{
    struct __CFNumber temp;
    return sentrycrashmem_copySafely(datePtr, &temp, sizeof(temp));
}

static int
numberDescription(const void *object, char *buffer, int bufferLength)
{
    char *pBuffer = buffer;
    char *pEnd = buffer + bufferLength;

    pBuffer += objectDescription(object, pBuffer, (int)(pEnd - pBuffer));

    if (sentrycrashobjc_numberIsFloat(object)) {
        Float64 value = sentrycrashobjc_numberAsFloat(object);
        pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": %lf", value);
    } else {
        int64_t value = sentrycrashobjc_numberAsInteger(object);
        pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": %" PRId64, value);
    }

    return (int)(pBuffer - buffer);
}

static bool
taggedNumberIsValid(const void *const object)
{
    return isValidTaggedPointer(object) && isTaggedPointerNSNumber(object);
}

static int
taggedNumberDescription(const void *object, char *buffer, int bufferLength)
{
    char *pBuffer = buffer;
    char *pEnd = buffer + bufferLength;

    int64_t value = extractTaggedNSNumber(object);
    pBuffer += taggedObjectDescription(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": %" PRId64, value);

    return (int)(pBuffer - buffer);
}

//======================================================================
#pragma mark - NSArray -
//======================================================================

struct NSArray {
    struct {
        void *isa;
        CFIndex count;
        id firstEntry;
    } basic;
};

static inline bool
nsarrayIsMutable(const void *const arrayPtr)
{
    return getClassDataFromObject(arrayPtr)->isMutable;
}

static inline bool
nsarrayIsValid(const void *const arrayPtr)
{
    struct NSArray temp;
    return sentrycrashmem_copySafely(arrayPtr, &temp, sizeof(temp.basic));
}

static inline int
nsarrayCount(const void *const arrayPtr)
{
    const struct NSArray *array = arrayPtr;
    return array->basic.count < 0 ? 0 : (int)array->basic.count;
}

static int
nsarrayContents(const void *const arrayPtr, uintptr_t *contents, int count)
{
    const struct NSArray *array = arrayPtr;

    if (array->basic.count < (CFIndex)count) {
        if (array->basic.count <= 0) {
            return 0;
        }
        count = (int)array->basic.count;
    }
    // TODO: implement this (requires bit-field unpacking) in
    // sentrycrashobj_ivarValue
    if (nsarrayIsMutable(arrayPtr)) {
        return 0;
    }

    if (!sentrycrashmem_copySafely(
            &array->basic.firstEntry, contents, (int)sizeof(*contents) * count)) {
        return 0;
    }
    return count;
}

static inline bool
cfarrayIsValid(const void *const arrayPtr)
{
    struct __CFArray temp;
    if (!sentrycrashmem_copySafely(arrayPtr, &temp, sizeof(temp))) {
        return false;
    }
    const struct __CFArray *array = arrayPtr;
    if (__CFArrayGetType(array) == __kCFArrayDeque) {
        if (array->_store != NULL) {
            struct __CFArrayDeque deque;
            if (!sentrycrashmem_copySafely(array->_store, &deque, sizeof(deque))) {
                return false;
            }
        }
    }
    return true;
}

static inline const void *
cfarrayData(const void *const arrayPtr)
{
    return __CFArrayGetBucketsPtr(arrayPtr);
}

static inline int
cfarrayCount(const void *const arrayPtr)
{
    const struct __CFArray *array = arrayPtr;
    return array->_count < 0 ? 0 : (int)array->_count;
}

static int
cfarrayContents(const void *const arrayPtr, uintptr_t *contents, int count)
{
    const struct __CFArray *array = arrayPtr;
    if (array->_count < (CFIndex)count) {
        if (array->_count <= 0) {
            return 0;
        }
        count = (int)array->_count;
    }

    const void *firstEntry = cfarrayData(array);
    if (!sentrycrashmem_copySafely(firstEntry, contents, (int)sizeof(*contents) * count)) {
        return 0;
    }
    return count;
}

static bool
isCFArray(const void *const arrayPtr)
{
    const ClassData *data = getClassDataFromObject(arrayPtr);
    return data->subtype == ClassSubtypeCFArray;
}

int
sentrycrashobjc_arrayCount(const void *const arrayPtr)
{
    if (isCFArray(arrayPtr)) {
        return cfarrayCount(arrayPtr);
    }
    return nsarrayCount(arrayPtr);
}

int
sentrycrashobjc_arrayContents(const void *const arrayPtr, uintptr_t *contents, int count)
{
    if (isCFArray(arrayPtr)) {
        return cfarrayContents(arrayPtr, contents, count);
    }
    return nsarrayContents(arrayPtr, contents, count);
}

bool
arrayIsValid(const void *object)
{
    if (isCFArray(object)) {
        return cfarrayIsValid(object);
    }
    return nsarrayIsValid(object);
}

static int
arrayDescription(const void *object, char *buffer, int bufferLength)
{
    char *pBuffer = buffer;
    char *pEnd = buffer + bufferLength;

    pBuffer += objectDescription(object, pBuffer, (int)(pEnd - pBuffer));
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), ": [");

    if (pBuffer < pEnd - 1 && sentrycrashobjc_arrayCount(object) > 0) {
        uintptr_t contents = 0;
        if (sentrycrashobjc_arrayContents(object, &contents, 1) == 1) {
            pBuffer
                += sentrycrashobjc_getDescription((void *)contents, pBuffer, (int)(pEnd - pBuffer));
        }
    }
    pBuffer += stringPrintf(pBuffer, (int)(pEnd - pBuffer), "]");

    return (int)(pBuffer - buffer);
}

//======================================================================
#pragma mark - NSDictionary (BROKEN) -
//======================================================================

bool
sentrycrashobjc_dictionaryFirstEntry(const void *dict, uintptr_t *key, uintptr_t *value)
{
    // TODO: This is broken.

    // Ensure memory is valid.
    struct __CFBasicHash copy;
    if (!sentrycrashmem_copySafely(dict, &copy, sizeof(copy))) {
        return false;
    }

    struct __CFBasicHash *ht = (struct __CFBasicHash *)dict;
    uintptr_t *keys = (uintptr_t *)ht->pointers + ht->bits.keys_offset;
    uintptr_t *values = (uintptr_t *)ht->pointers;

    // Dereference key and value pointers.
    if (!sentrycrashmem_copySafely(keys, &keys, sizeof(keys))) {
        return false;
    }

    if (!sentrycrashmem_copySafely(values, &values, sizeof(values))) {
        return false;
    }

    // Copy to destination.
    if (!sentrycrashmem_copySafely(keys, key, sizeof(*key))) {
        return false;
    }
    if (!sentrycrashmem_copySafely(values, value, sizeof(*value))) {
        return false;
    }
    return true;
}

int
sentrycrashobjc_dictionaryCount(const void *dict)
{
    // TODO: Implement me
#pragma unused(dict)
    return 0;
}

//======================================================================
#pragma mark - General Queries -
//======================================================================

int
sentrycrashobjc_getDescription(void *object, char *buffer, int bufferLength)
{
    const ClassData *data = getClassDataFromObject(object);
    return data->description(object, buffer, bufferLength);
}

bool
sentrycrashobjc_isTaggedPointer(const void *const pointer)
{
    return isTaggedPointer(pointer);
}

bool
sentrycrashobjc_isValidTaggedPointer(const void *const pointer)
{
    return isValidTaggedPointer(pointer);
}

bool
sentrycrashobjc_isValidObject(const void *object)
{
    if (!isValidObject(object)) {
        return false;
    }
    const ClassData *data = getClassDataFromObject(object);
    return data->isValidObject(object);
}

SentryCrashObjCClassType
sentrycrashobjc_objectClassType(const void *object)
{
    const ClassData *data = getClassDataFromObject(object);
    return data->type;
}

//__NSArrayReversed
//__NSCFBoolean
//__NSCFDictionary
//__NSCFError
//__NSCFNumber
//__NSCFSet
//__NSCFString
//__NSDate
//__NSDictionaryI
//__NSDictionaryM
//__NSOrderedSetArrayProxy
//__NSOrderedSetI
//__NSOrderedSetM
//__NSOrderedSetReversed
//__NSOrderedSetSetProxy
//__NSPlaceholderArray
//__NSPlaceholderDate
//__NSPlaceholderDictionary
//__NSPlaceholderOrderedSet
//__NSPlaceholderSet
//__NSSetI
//__NSSetM
// NSArray
// NSCFArray
// NSCFBoolean
// NSCFDictionary
// NSCFError
// NSCFNumber
// NSCFSet
// NSCheapMutableString
// NSClassicHashTable
// NSClassicMapTable
// SConcreteHashTable
// NSConcreteMapTable
// NSConcreteValue
// NSDate
// NSDecimalNumber
// NSDecimalNumberPlaceholder
// NSDictionary
// NSError
// NSException
// NSHashTable
// NSMutableArray
// NSMutableDictionary
// NSMutableIndexSet
// NSMutableOrderedSet
// NSMutableRLEArray
// NSMutableSet
// NSMutableString
// NSMutableStringProxy
// NSNumber
// NSOrderedSet
// NSPlaceholderMutableString
// NSPlaceholderNumber
// NSPlaceholderString
// NSRLEArray
// NSSet
// NSSimpleCString
// NSString
// NSURL
