/*
 *  TouchEvents.h
 *  TouchSynthesis
 *
 *  Created by Nathan Vander Wilt on 1/13/10.
 *  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
 *
 */

#include <ApplicationServices/ApplicationServices.h>


/* these for info */

extern const CFStringRef kTLInfoKeyDeviceID;	// required for touches
extern const CFStringRef kTLInfoKeyTimestamp;
extern const CFStringRef kTLInfoKeyGestureSubtype;
extern const CFStringRef kTLInfoKeyGesturePhase;
extern const CFStringRef kTLInfoKeyMagnification;
extern const CFStringRef kTLInfoKeyRotation;	// degrees
extern const CFStringRef kTLInfoKeySwipeDirection;
extern const CFStringRef kTLInfoKeyNextSubtype;

enum {
	kTLInfoSubtypeRotate = 0x05,
	kTLInfoSubtypeSub6,	// may be panning/scrolling
	kTLInfoSubtypeMagnify = 0x08,
	kTLInfoSubtypeGesture = 0x0B,
	kTLInfoSubtypeSwipe = 0x10,
	kTLInfoSubtypeBeginGesture = 0x3D,
	kTLInfoSubtypeEndGesture
};
typedef uint32_t TLInfoSubtype;

enum {
    kTLInfoSwipeUp = 1,
    kTLInfoSwipeDown = 2,
    kTLInfoSwipeLeft = 4,
    kTLInfoSwipeRight = 8
};
typedef uint32_t TLInfoSwipeDirection;


/* these for touches */

extern const CFStringRef kTLEventKeyType;
extern const CFStringRef kTLEventKeyTimestamp;
extern const CFStringRef kTLEventKeyOptions;

extern const CFStringRef kTLEventKeyPositionX;
extern const CFStringRef kTLEventKeyPositionY;
extern const CFStringRef kTLEventKeyPositionZ;

extern const CFStringRef kTLEventKeyTransducerIndex;
extern const CFStringRef kTLEventKeyTransducerType;
extern const CFStringRef kTLEventKeyIdentity;
extern const CFStringRef kTLEventKeyEventMask;

extern const CFStringRef kTLEventKeyButtonMask;
extern const CFStringRef kTLEventKeyTipPressure;
extern const CFStringRef kTLEventKeyBarrelPressure;
extern const CFStringRef kTLEventKeyTwist;

extern const CFStringRef kTLEventKeyQuality;
extern const CFStringRef kTLEventKeyDensity;
extern const CFStringRef kTLEventKeyIrregularity;
extern const CFStringRef kTLEventKeyMajorRadius;
extern const CFStringRef kTLEventKeyMinorRadius;


CGEventRef tl_CGEventCreateFromGesture(CFDictionaryRef info, CFArrayRef touches);
