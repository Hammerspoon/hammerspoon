//
//  MIKMIDICompilerCompatibility.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/4/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

/*
 This header contains macros used to adopt new compiler features without breaking support for building MIKMIDI
 with older compiler versions.
 */

// Keep older versions of the compiler happy
#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#define nonnullable
#define __nullable
#endif

#ifndef MIKArrayOf
#if __has_feature(objc_generics)

#define MIKArrayOf(TYPE) NSArray<TYPE>
#define MIKArrayOfKindOf(TYPE) NSArray<__kindof TYPE>

#define MIKMutableArrayOf(TYPE) NSMutableArray<TYPE>

#define MIKSetOf(TYPE) NSSet<TYPE>
#define MIKMutableSetOf(TYPE) NSMutableSet<TYPE>

#define MIKMapTableOf(KEYTYPE, OBJTYPE) NSMapTable<KEYTYPE, OBJTYPE>

#else

#define MIKArrayOf(TYPE) NSArray
#define MIKArrayOfKindOf(TYPE) NSArray

#define MIKMutableArrayOf(TYPE) NSMutableArray

#define MIKSetOf(TYPE) NSSet
#define MIKMutableSetOf(TYPE) NSMutableSet

#define MIKMapTableOf(KEYTYPE, OBJTYPE) NSMapTable

#endif
#endif // #ifndef MIKArrayOf

// Weak support

// On OS X 10.7, many classes (e.g. NSViewController) can't be the target of a weak
// reference, so we use unsafe_unretained there.
#if TARGET_OS_IPHONE || (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8)
#define MIKTargetSafeWeak weak
#else
#define MIKTargetSafeWeak unsafe_unretained
#endif