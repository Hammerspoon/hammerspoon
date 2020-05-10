//
//  SentryCrashObjCApple.h
//
//  Created by Karl Stenerud on 2012-08-30.
//
// Copyright (c) 2011 Apple Inc. All rights reserved.
//
// This file contains Original Code and/or Modifications of Original Code
// as defined in and that are subject to the Apple Public Source License
// Version 2.0 (the 'License'). You may not use this file except in
// compliance with the License. Please obtain a copy of the License at
// http://www.opensource.apple.com/apsl/ and read it before using this
// file.
//

// This file contains structures and constants copied from Apple header
// files, arranged for use in SentryCrashObjC.

#ifndef HDR_SentryCrashObjCApple_h
#define HDR_SentryCrashObjCApple_h

#ifdef __cplusplus
extern "C" {
#endif


#include <objc/objc.h>
#include <CoreFoundation/CoreFoundation.h>


#define MAKE_LIST_T(TYPE) \
typedef struct TYPE##_list_t { \
    uint32_t entsizeAndFlags; \
    uint32_t count; \
    TYPE##_t first; \
} TYPE##_list_t; \
typedef TYPE##_list_t TYPE##_array_t

#define OBJC_OBJECT(NAME) \
NAME { \
    Class isa  OBJC_ISA_AVAILABILITY;


// ======================================================================
#pragma mark - objc4-680/runtime/objc-msg-x86_64.s -
// and objc4-680/runtime/objc-msg-arm64.s
// ======================================================================

#if __x86_64__
#   define ISA_TAG_MASK 1UL
#   define ISA_MASK     0x00007ffffffffff8UL
#elif defined(__arm64__)
#   define ISA_TAG_MASK 1UL
#   define ISA_MASK_OLD 0x00000001fffffff8UL
#   define ISA_MASK     0x0000000ffffffff8UL
#else
#   define ISA_TAG_MASK 0UL
#   define ISA_MASK     ~1UL
#endif


// ======================================================================
#pragma mark - objc4-680/runtime/objc-config.h -
// ======================================================================

// Define SUPPORT_TAGGED_POINTERS=1 to enable tagged pointer objects
// Be sure to edit tagged pointer SPI in objc-internal.h as well.
#if !(__LP64__)
#   define SUPPORT_TAGGED_POINTERS 0
#else
#   define SUPPORT_TAGGED_POINTERS 1
#endif

// Define SUPPORT_MSB_TAGGED_POINTERS to use the MSB
// as the tagged pointer marker instead of the LSB.
// Be sure to edit tagged pointer SPI in objc-internal.h as well.
#if !SUPPORT_TAGGED_POINTERS  ||  !TARGET_OS_IPHONE
#   define SUPPORT_MSB_TAGGED_POINTERS 0
#else
#   define SUPPORT_MSB_TAGGED_POINTERS 1
#endif


// ======================================================================
#pragma mark - objc4-680/runtime/objc-object.h -
// ======================================================================

#if SUPPORT_TAGGED_POINTERS

// SentryCrash: The original values wouldn't have worked. The slot shift and mask
// were incorrect.
#define TAG_COUNT 8
//#define TAG_SLOT_MASK 0xf
#define TAG_SLOT_MASK 0x07

#if SUPPORT_MSB_TAGGED_POINTERS
#   define TAG_MASK (1ULL<<63)
#   define TAG_SLOT_SHIFT 60
#   define TAG_PAYLOAD_LSHIFT 4
#   define TAG_PAYLOAD_RSHIFT 4
#else
#   define TAG_MASK 1
//#   define TAG_SLOT_SHIFT 0
#   define TAG_SLOT_SHIFT 1
#   define TAG_PAYLOAD_LSHIFT 0
#   define TAG_PAYLOAD_RSHIFT 4
#endif

#endif

// ======================================================================
#pragma mark - objc4-680/runtime/objc-internal.h -
// ======================================================================

enum
{
    OBJC_TAG_NSAtom            = 0,
    OBJC_TAG_1                 = 1,
    OBJC_TAG_NSString          = 2,
    OBJC_TAG_NSNumber          = 3,
    OBJC_TAG_NSIndexPath       = 4,
    OBJC_TAG_NSManagedObjectID = 5,
    OBJC_TAG_NSDate            = 6,
    OBJC_TAG_7                 = 7
};



// ======================================================================
#pragma mark - objc4-680/runtime/objc-os.h -
// ======================================================================

#ifdef __LP64__
#   define WORD_SHIFT 3UL
#   define WORD_MASK 7UL
#   define WORD_BITS 64
#else
#   define WORD_SHIFT 2UL
#   define WORD_MASK 3UL
#   define WORD_BITS 32
#endif


// ======================================================================
#pragma mark - objc4-680/runtime/runtime.h -
// ======================================================================

typedef struct objc_cache *Cache;


// ======================================================================
#pragma mark - objc4-680/runtime/objc-runtime-new.h -
// ======================================================================

typedef struct method_t {
    SEL name;
    const char *types;
    IMP imp;
} method_t;

MAKE_LIST_T(method);

typedef struct ivar_t {
#if __x86_64__
    // *offset was originally 64-bit on some x86_64 platforms.
    // We read and write only 32 bits of it.
    // Some metadata provides all 64 bits. This is harmless for unsigned
    // little-endian values.
    // Some code uses all 64 bits. class_addIvar() over-allocates the
    // offset for their benefit.
#endif
    int32_t *offset;
    const char *name;
    const char *type;
    // alignment is sometimes -1; use alignment() instead
    uint32_t alignment_raw;
    uint32_t size;
} ivar_t;

MAKE_LIST_T(ivar);

typedef struct property_t {
    const char *name;
    const char *attributes;
} property_t;

MAKE_LIST_T(property);

typedef struct OBJC_OBJECT(protocol_t)
    const char *mangledName;
    struct protocol_list_t *protocols;
    method_list_t *instanceMethods;
    method_list_t *classMethods;
    method_list_t *optionalInstanceMethods;
    method_list_t *optionalClassMethods;
    property_list_t *instanceProperties;
    uint32_t size;   // sizeof(protocol_t)
    uint32_t flags;
    // Fields below this point are not always present on disk.
    const char **extendedMethodTypes;
    const char *_demangledName;
} protocol_t;

MAKE_LIST_T(protocol);

// Values for class_ro_t->flags
// These are emitted by the compiler and are part of the ABI.
// class is a metaclass
#define RO_META               (1<<0)
// class is a root class
#define RO_ROOT               (1<<1)

typedef struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    const uint8_t * ivarLayout;

    const char * name;
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;
} class_ro_t;

typedef struct class_rw_t {
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    method_array_t methods;
    property_array_t properties;
    protocol_array_t protocols;

    Class firstSubclass;
    Class nextSiblingClass;

    char *demangledName;
} class_rw_t;

typedef struct class_t {
    struct class_t *isa;
    struct class_t *superclass;
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    Cache cache;
#pragma clang diagnostic pop
    IMP *vtable;
    uintptr_t data_NEVER_USE;  // class_rw_t * plus custom rr/alloc flags
} class_t;


// ======================================================================
#pragma mark - CF-1153.18/CFRuntime.h -
// ======================================================================

typedef struct __CFRuntimeBase {
    uintptr_t _cfisa;
    uint8_t _cfinfo[4];
#if __LP64__
    uint32_t _rc;
#endif
} CFRuntimeBase;


// ======================================================================
#pragma mark - CF-1153.18/CFInternal.h -
// ======================================================================

#if defined(__BIG_ENDIAN__)
#define __CF_BIG_ENDIAN__ 1
#define __CF_LITTLE_ENDIAN__ 0
#endif

#if defined(__LITTLE_ENDIAN__)
#define __CF_LITTLE_ENDIAN__ 1
#define __CF_BIG_ENDIAN__ 0
#endif

#define CF_INFO_BITS (!!(__CF_BIG_ENDIAN__) * 3)
#define CF_RC_BITS (!!(__CF_LITTLE_ENDIAN__) * 3)

/* Bit manipulation macros */
/* Bits are numbered from 31 on left to 0 on right */
/* May or may not work if you use them on bitfields in types other than UInt32, bitfields the full width of a UInt32, or anything else for which they were not designed. */
/* In the following, N1 and N2 specify an inclusive range N2..N1 with N1 >= N2 */
#define __CFBitfieldMask(N1, N2)	((((UInt32)~0UL) << (31UL - (N1) + (N2))) >> (31UL - N1))
#define __CFBitfieldGetValue(V, N1, N2)	(((V) & __CFBitfieldMask(N1, N2)) >> (N2))


// ======================================================================
#pragma mark - CF-1153.18/CFString.c -
// ======================================================================

// This is separate for C++
struct __notInlineMutable {
    void *buffer;
    CFIndex length;
    CFIndex capacity;                           // Capacity in bytes
    unsigned int hasGap:1;                      // Currently unused
    unsigned int isFixedCapacity:1;
    unsigned int isExternalMutable:1;
    unsigned int capacityProvidedExternally:1;
#if __LP64__
    unsigned long desiredCapacity:60;
#else
    unsigned long desiredCapacity:28;
#endif
    CFAllocatorRef contentsAllocator;           // Optional
};                             // The only mutable variant for CFString

/* !!! Never do sizeof(CFString); the union is here just to make it easier to access some fields.
 */
struct __CFString {
    CFRuntimeBase base;
    union {	// In many cases the allocated structs are smaller than these
        struct __inline1 {
            CFIndex length;
        } inline1;                                      // Bytes follow the length
        struct __notInlineImmutable1 {
            void *buffer;                               // Note that the buffer is in the same place for all non-inline variants of CFString
            CFIndex length;
            CFAllocatorRef contentsDeallocator;		// Optional; just the dealloc func is used
        } notInlineImmutable1;                          // This is the usual not-inline immutable CFString
        struct __notInlineImmutable2 {
            void *buffer;
            CFAllocatorRef contentsDeallocator;		// Optional; just the dealloc func is used
        } notInlineImmutable2;                          // This is the not-inline immutable CFString when length is stored with the contents (first byte)
        struct __notInlineMutable notInlineMutable;
    } variants;
};

/*
 I = is immutable
 E = not inline contents
 U = is Unicode
 N = has NULL byte
 L = has length byte
 D = explicit deallocator for contents (for mutable objects, allocator)
 C = length field is CFIndex (rather than UInt32); only meaningful for 64-bit, really
 if needed this bit (valuable real-estate) can be given up for another bit elsewhere, since this info is needed just for 64-bit

 Also need (only for mutable)
 F = is fixed
 G = has gap
 Cap, DesCap = capacity

 B7 B6 B5 B4 B3 B2 B1 B0
 U  N  L  C  I

 B6 B5
 0  0   inline contents
 0  1   E (freed with default allocator)
 1  0   E (not freed)
 1  1   E D

 !!! Note: Constant CFStrings use the bit patterns:
 C8 (11001000 = default allocator, not inline, not freed contents; 8-bit; has NULL byte; doesn't have length; is immutable)
 D0 (11010000 = default allocator, not inline, not freed contents; Unicode; is immutable)
 The bit usages should not be modified in a way that would effect these bit patterns.
 */

enum {
    __kCFFreeContentsWhenDoneMask = 0x020,
    __kCFFreeContentsWhenDone = 0x020,
    __kCFContentsMask = 0x060,
    __kCFHasInlineContents = 0x000,
    __kCFNotInlineContentsNoFree = 0x040,		// Don't free
    __kCFNotInlineContentsDefaultFree = 0x020,	// Use allocator's free function
    __kCFNotInlineContentsCustomFree = 0x060,		// Use a specially provided free function
    __kCFHasContentsAllocatorMask = 0x060,
    __kCFHasContentsAllocator = 0x060,		// (For mutable strings) use a specially provided allocator
    __kCFHasContentsDeallocatorMask = 0x060,
    __kCFHasContentsDeallocator = 0x060,
    __kCFIsMutableMask = 0x01,
    __kCFIsMutable = 0x01,
    __kCFIsUnicodeMask = 0x10,
    __kCFIsUnicode = 0x10,
    __kCFHasNullByteMask = 0x08,
    __kCFHasNullByte = 0x08,
    __kCFHasLengthByteMask = 0x04,
    __kCFHasLengthByte = 0x04,
    // !!! Bit 0x02 has been freed up
};


// !!! Assumptions:
// Mutable strings are not inline
// Compile-time constant strings are not inline
// Mutable strings always have explicit length (but they might also have length byte and null byte)
// If there is an explicit length, always use that instead of the length byte (length byte is useful for quickly returning pascal strings)
// Never look at the length byte for the length; use __CFStrLength or __CFStrLength2

/* The following set of functions and macros need to be updated on change to the bit configuration
 */
CF_INLINE Boolean __CFStrIsMutable(CFStringRef str)                 {return (str->base._cfinfo[CF_INFO_BITS] & __kCFIsMutableMask) == __kCFIsMutable;}
CF_INLINE Boolean __CFStrIsInline(CFStringRef str)                  {return (str->base._cfinfo[CF_INFO_BITS] & __kCFContentsMask) == __kCFHasInlineContents;}
CF_INLINE Boolean __CFStrFreeContentsWhenDone(CFStringRef str)      {return (str->base._cfinfo[CF_INFO_BITS] & __kCFFreeContentsWhenDoneMask) == __kCFFreeContentsWhenDone;}
CF_INLINE Boolean __CFStrHasContentsDeallocator(CFStringRef str)    {return (str->base._cfinfo[CF_INFO_BITS] & __kCFHasContentsDeallocatorMask) == __kCFHasContentsDeallocator;}
CF_INLINE Boolean __CFStrIsUnicode(CFStringRef str)                 {return (str->base._cfinfo[CF_INFO_BITS] & __kCFIsUnicodeMask) == __kCFIsUnicode;}
CF_INLINE Boolean __CFStrIsEightBit(CFStringRef str)                {return (str->base._cfinfo[CF_INFO_BITS] & __kCFIsUnicodeMask) != __kCFIsUnicode;}
CF_INLINE Boolean __CFStrHasNullByte(CFStringRef str)               {return (str->base._cfinfo[CF_INFO_BITS] & __kCFHasNullByteMask) == __kCFHasNullByte;}
CF_INLINE Boolean __CFStrHasLengthByte(CFStringRef str)             {return (str->base._cfinfo[CF_INFO_BITS] & __kCFHasLengthByteMask) == __kCFHasLengthByte;}
CF_INLINE Boolean __CFStrHasExplicitLength(CFStringRef str)         {return (str->base._cfinfo[CF_INFO_BITS] & (__kCFIsMutableMask | __kCFHasLengthByteMask)) != __kCFHasLengthByte;}	// Has explicit length if (1) mutable or (2) not mutable and no length byte
CF_INLINE Boolean __CFStrIsConstant(CFStringRef str) {
#if __LP64__
    return str->base._rc == 0;
#else
    return (str->base._cfinfo[CF_RC_BITS]) == 0;
#endif
}

/* Returns ptr to the buffer (which might include the length byte).
 */
CF_INLINE const void *__CFStrContents(CFStringRef str) {
    if (__CFStrIsInline(str)) {
        return (const void *)(((uintptr_t)&(str->variants)) + (__CFStrHasExplicitLength(str) ? sizeof(CFIndex) : 0));
    } else {	// Not inline; pointer is always word 2
        return str->variants.notInlineImmutable1.buffer;
    }
}


// ======================================================================
#pragma mark - CF-1153.18/CFURL.c -
// ======================================================================

struct __CFURL {
    CFRuntimeBase _cfBase;
    UInt32 _flags;
    CFStringEncoding _encoding; // The encoding to use when asked to remove percent escapes
    CFStringRef _string; // Never NULL
    CFURLRef _base;
    struct _CFURLAdditionalData* _extra;
    void *_resourceInfo;    // For use by CoreServicesInternal to cache property values. Retained and released by CFURL.
    CFRange _ranges[1]; // variable length (1 to 9) array of ranges
};


// ======================================================================
#pragma mark - CF-1153.18/CFDate.c -
// ======================================================================

struct __CFDate {
    // According to CFDate.c the structure is a CFRuntimeBase followed
    // by the time. In fact, it's only an isa pointer followed by the time.
    //struct CFRuntimeBase _base;
    uintptr_t _cfisa;
    CFAbsoluteTime _time;       /* immutable */
};


// ======================================================================
#pragma mark - CF-1153.18/CFNumber.c -
// ======================================================================

struct __CFNumber {
    CFRuntimeBase _base;
    uint64_t _pad; // need this space here for the constant objects
    /* 0 or 8 more bytes allocated here */
};


// ======================================================================
#pragma mark - CF-1153.18/CFArray.c -
// ======================================================================

struct __CFArrayBucket {
    const void *_item;
};

struct __CFArrayDeque {
    uintptr_t _leftIdx;
    uintptr_t _capacity;
    /* struct __CFArrayBucket buckets follow here */
};

struct __CFArray {
    CFRuntimeBase _base;
    CFIndex _count;		/* number of objects */
    CFIndex _mutations;
    int32_t _mutInProgress;
    /* __strong */ void *_store;           /* can be NULL when MutableDeque */
};

/* Flag bits */
enum {		/* Bits 0-1 */
    __kCFArrayImmutable = 0,
    __kCFArrayDeque = 2,
};

enum {		/* Bits 2-3 */
    __kCFArrayHasNullCallBacks = 0,
    __kCFArrayHasCFTypeCallBacks = 1,
    __kCFArrayHasCustomCallBacks = 3	/* callbacks are at end of header */
};

CF_INLINE CFIndex __CFArrayGetType(CFArrayRef array) {
    return __CFBitfieldGetValue(((const CFRuntimeBase *)array)->_cfinfo[CF_INFO_BITS], 1, 0);
}

CF_INLINE CFIndex __CFArrayGetSizeOfType(CFIndex t) {
    CFIndex size = 0;
    size += sizeof(struct __CFArray);
    if (__CFBitfieldGetValue((unsigned long)t, 3, 2) == __kCFArrayHasCustomCallBacks) {
        size += sizeof(CFArrayCallBacks);
    }
    return size;
}

/* Only applies to immutable and mutable-deque-using arrays;
 * Returns the bucket holding the left-most real value in the latter case. */
CF_INLINE struct __CFArrayBucket *__CFArrayGetBucketsPtr(CFArrayRef array) {
    switch (__CFArrayGetType(array)) {
        case __kCFArrayImmutable:
            return (struct __CFArrayBucket *)((uint8_t *)array + __CFArrayGetSizeOfType(((CFRuntimeBase *)array)->_cfinfo[CF_INFO_BITS]));
        case __kCFArrayDeque: {
            struct __CFArrayDeque *deque = (struct __CFArrayDeque *)array->_store;
            return (struct __CFArrayBucket *)((uint8_t *)deque + sizeof(struct __CFArrayDeque) + deque->_leftIdx * sizeof(struct __CFArrayBucket));
        }
    }
    return NULL;
}


// ======================================================================
#pragma mark - CF-1153.18/CFBasicHash.h -
// ======================================================================

typedef struct __CFBasicHash *CFBasicHashRef;
typedef const struct __CFBasicHash *CFConstBasicHashRef;

typedef struct __CFBasicHashCallbacks CFBasicHashCallbacks;

struct __CFBasicHashCallbacks {
    uintptr_t (*retainValue)(CFAllocatorRef alloc, uintptr_t stack_value);	// Return 2nd arg or new value
    uintptr_t (*retainKey)(CFAllocatorRef alloc, uintptr_t stack_key);	// Return 2nd arg or new key
    void (*releaseValue)(CFAllocatorRef alloc, uintptr_t stack_value);
    void (*releaseKey)(CFAllocatorRef alloc, uintptr_t stack_key);
    Boolean (*equateValues)(uintptr_t coll_value1, uintptr_t stack_value2); // 1st arg is in-collection value, 2nd arg is probe parameter OR in-collection value for a second collection
    Boolean (*equateKeys)(uintptr_t coll_key1, uintptr_t stack_key2); // 1st arg is in-collection key, 2nd arg is probe parameter
    CFHashCode (*hashKey)(uintptr_t stack_key);
    uintptr_t (*getIndirectKey)(uintptr_t coll_value);	// Return key; 1st arg is in-collection value
    CFStringRef (*copyValueDescription)(uintptr_t stack_value);
    CFStringRef (*copyKeyDescription)(uintptr_t stack_key);
};


// ======================================================================
#pragma mark - CF-1153.18/CFBasicHash.c -
// ======================================================================

// Prime numbers. Values above 100 have been adjusted up so that the
// malloced block size will be just below a multiple of 512; values
// above 1200 have been adjusted up to just below a multiple of 4096.
static const uintptr_t __CFBasicHashTableSizes[64] = {
    0, 3, 7, 13, 23, 41, 71, 127, 191, 251, 383, 631, 1087, 1723,
    2803, 4523, 7351, 11959, 19447, 31231, 50683, 81919, 132607,
    214519, 346607, 561109, 907759, 1468927, 2376191, 3845119,
    6221311, 10066421, 16287743, 26354171, 42641881, 68996069,
    111638519, 180634607, 292272623, 472907251,
#if __LP64__
    765180413UL, 1238087663UL, 2003267557UL, 3241355263UL, 5244622819UL,
#if 0
    8485977589UL, 13730600407UL, 22216578047UL, 35947178479UL,
    58163756537UL, 94110934997UL, 152274691561UL, 246385626107UL,
    398660317687UL, 645045943807UL, 1043706260983UL, 1688752204787UL,
    2732458465769UL, 4421210670577UL, 7153669136377UL,
    11574879807461UL, 18728548943849UL, 30303428750843UL
#endif
#endif
};

typedef union {
    uintptr_t neutral;
    void* Xstrong; // Changed from type 'id'
    void* Xweak; // Changed from type 'id'
} CFBasicHashValue;

struct __CFBasicHash {
    CFRuntimeBase base;
    struct { // 192 bits
        uint16_t mutations;
        uint8_t hash_style:2;
        uint8_t keys_offset:1;
        uint8_t counts_offset:2;
        uint8_t counts_width:2;
        uint8_t hashes_offset:2;
        uint8_t strong_values:1;
        uint8_t strong_keys:1;
        uint8_t weak_values:1;
        uint8_t weak_keys:1;
        uint8_t int_values:1;
        uint8_t int_keys:1;
        uint8_t indirect_keys:1;
        uint32_t used_buckets;      /* number of used buckets */
        uint64_t deleted:16;
        uint64_t num_buckets_idx:8; /* index to number of buckets */
        uint64_t __kret:10;
        uint64_t __vret:10;
        uint64_t __krel:10;
        uint64_t __vrel:10;
        uint64_t __:1;
        uint64_t null_rc:1;
        uint64_t fast_grow:1;
        uint64_t finalized:1;
        uint64_t __kdes:10;
        uint64_t __vdes:10;
        uint64_t __kequ:10;
        uint64_t __vequ:10;
        uint64_t __khas:10;
        uint64_t __kget:10;
    } bits;
    void *pointers[1];
};

CF_INLINE CFBasicHashValue *__CFBasicHashGetValues(CFConstBasicHashRef ht) {
    return (CFBasicHashValue *)ht->pointers[0];
}

CF_INLINE CFBasicHashValue *__CFBasicHashGetKeys(CFConstBasicHashRef ht) {
    return (CFBasicHashValue *)ht->pointers[ht->bits.keys_offset];
}

CF_INLINE void *__CFBasicHashGetCounts(CFConstBasicHashRef ht) {
    return (void *)ht->pointers[ht->bits.counts_offset];
}

CF_INLINE uintptr_t __CFBasicHashGetSlotCount(CFConstBasicHashRef ht, CFIndex idx) {
    void *counts = __CFBasicHashGetCounts(ht);
    switch (ht->bits.counts_width) {
        case 0: return ((uint8_t *)counts)[idx];
        case 1: return ((uint16_t *)counts)[idx];
        case 2: return ((uint32_t *)counts)[idx];
        case 3: return (uintptr_t)((uint64_t *)counts)[idx];
    }
    return 0;
}


#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashObjCApple_h
