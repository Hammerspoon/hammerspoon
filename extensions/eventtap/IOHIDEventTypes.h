/*
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * Copyright (c) 1999-2003 Apple Computer, Inc.  All Rights Reserved.
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

#ifndef _IOKIT_HID_IOHIDEVENTTYPES_H
#define _IOKIT_HID_IOHIDEVENTTYPES_H /* { */

#include <TargetConditionals.h>
#include <IOKit/IOTypes.h>

#define IRONSIDE_AVAILABLE 1

#if TARGET_OS_IPHONE
    #ifndef IRONSIDE_AVAILABLE
    #ifndef RC_SEED_BUILD
        #define IRONSIDE_AVAILABLE 1
    #endif
    #endif
#else
    //#include <ironside.h>
#endif

#define IOHIDEventTypeMask(type) (1LL<<type)
#define IOHIDEventFieldBase(type) (type << 16)
/*!
    @typedef IOHIDEventType
    @abstract The type of event represented by an IOHIDEventRef.
    @discussion It is possible that a single IOHIDEventRef can conform to
    multiple event types through the use of sub events.  For futher information
    as to how to determinte the type of event please reference IOHIDEventGetType 
    and IOHIDEventConformsTo.
    @constant kIOHIDEventTypeNULL
    @constant kIOHIDEventTypeVendorDefined
    @constant kIOHIDEventTypeButton
    @constant kIOHIDEventTypeKeyboard
    @constant kIOHIDEventTypeTranslation
    @constant kIOHIDEventTypeRotation
    @constant kIOHIDEventTypeScroll
    @constant kIOHIDEventTypeScale
    @constant kIOHIDEventTypeZoom
    @constant kIOHIDEventTypeVelocity
    @constant kIOHIDEventTypeOrientation
    @constant kIOHIDEventTypeDigitizer
    @constant kIOHIDEventTypeAmbientLightSensor
    @constant kIOHIDEventTypeAccelerometer
    @constant kIOHIDEventTypeProximity
    @constant kIOHIDEventTypeTemperature
    @constant kIOHIDEventTypeNavigationSwipe
    @constant kIOHIDEventTypePointer
    @constant kIOHIDEventTypeProgress
    @constant kIOHIDEventTypeMultiAxisPointer
    @constant kIOHIDEventTypeGyro
    @constant kIOHIDEventTypeCompass
    @constant kIOHIDEventTypeZoomToggle
    @constant kIOHIDEventTypeDockSwipe
    @constant kIOHIDEventTypeSymbolicHotKey
    @constant kIOHIDEventTypePower
    @constant kIOHIDEventTypeLED
    @constant kIOHIDEventTypeFluidTouchGesture
    @constant kIOHIDEventTypeBoundaryScroll
    @constant kIOHIDEventTypeBiometric
    @constant kIOHIDEventTypeSwipe DEPRECATED
    @constant kIOHIDEventTypeMouse DEPRECATED

*/
enum {
    kIOHIDEventTypeNULL,                    // 0
    kIOHIDEventTypeVendorDefined,
    kIOHIDEventTypeButton,
    kIOHIDEventTypeKeyboard, 
    kIOHIDEventTypeTranslation,
    kIOHIDEventTypeRotation,                // 5
    kIOHIDEventTypeScroll,
    kIOHIDEventTypeScale,
    kIOHIDEventTypeZoom,
    kIOHIDEventTypeVelocity,
    kIOHIDEventTypeOrientation,             // 10
    kIOHIDEventTypeDigitizer,
    kIOHIDEventTypeAmbientLightSensor,
    kIOHIDEventTypeAccelerometer,
    kIOHIDEventTypeProximity,
    kIOHIDEventTypeTemperature,             // 15
    kIOHIDEventTypeNavigationSwipe,
    kIOHIDEventTypePointer,
    kIOHIDEventTypeProgress,
    kIOHIDEventTypeMultiAxisPointer,
    kIOHIDEventTypeGyro,                    // 20
    kIOHIDEventTypeCompass,
    kIOHIDEventTypeZoomToggle,
    kIOHIDEventTypeDockSwipe,               // just like kIOHIDEventTypeNavigationSwipe, but intended for consumption by Dock
    kIOHIDEventTypeSymbolicHotKey,
    kIOHIDEventTypePower,                   // 25
    kIOHIDEventTypeLED,
    kIOHIDEventTypeFluidTouchGesture,       // This will eventually superseed Navagation and Dock swipes
    kIOHIDEventTypeBoundaryScroll,
    kIOHIDEventTypeBiometric,
    kIOHIDEventTypeUnicode,                 // 30
    kIOHIDEventTypeAtmosphericPressure,
#if IRONSIDE_AVAILABLE // {
    kIOHIDEventTypeForce,
#else // } IRONSIDE_AVAILABLE {
    kIOHIDEventTypeUndefined,
#endif // } IRONSIDE_AVAILABLE
    
    kIOHIDEventTypeCount, // This should always be last
    
    
    // DEPRECATED:
    kIOHIDEventTypeSwipe = kIOHIDEventTypeNavigationSwipe,
    kIOHIDEventTypeMouse = kIOHIDEventTypePointer
};
typedef uint32_t IOHIDEventType;

/* 
    @typedef IOHIDEventField
    @abstract Keys used to set and get individual event fields.
*/
enum {
    kIOHIDEventFieldIsRelative = IOHIDEventFieldBase(kIOHIDEventTypeNULL),
    kIOHIDEventFieldIsCollection,
    kIOHIDEventFieldIsPixelUnits,
    kIOHIDEventFieldIsCenterOrigin,
    kIOHIDEventFieldIsBuiltIn
};

enum {
    kIOHIDEventFieldVendorDefinedUsagePage = IOHIDEventFieldBase(kIOHIDEventTypeVendorDefined),
    kIOHIDEventFieldVendorDefinedUsage,
    kIOHIDEventFieldVendorDefinedVersion,
    kIOHIDEventFieldVendorDefinedDataLength,
    kIOHIDEventFieldVendorDefinedData
};

enum  {
    kIOHIDEventFieldButtonMask = IOHIDEventFieldBase(kIOHIDEventTypeButton),
    kIOHIDEventFieldButtonNumber,
    kIOHIDEventFieldButtonClickCount,
    kIOHIDEventFieldButtonPressure,
    kIOHIDEventFieldButtonState
};

enum {
    kIOHIDEventFieldTranslationX = IOHIDEventFieldBase(kIOHIDEventTypeTranslation),
    kIOHIDEventFieldTranslationY,
    kIOHIDEventFieldTranslationZ
};

enum {
    kIOHIDEventFieldRotationX = IOHIDEventFieldBase(kIOHIDEventTypeRotation),
    kIOHIDEventFieldRotationY,
    kIOHIDEventFieldRotationZ
};

enum {
    kIOHIDEventFieldScrollX = IOHIDEventFieldBase(kIOHIDEventTypeScroll),
    kIOHIDEventFieldScrollY,
    kIOHIDEventFieldScrollZ,
    kIOHIDEventFieldScrollIsPixels
};

enum {
    kIOHIDEventFieldScaleX = IOHIDEventFieldBase(kIOHIDEventTypeScale),
    kIOHIDEventFieldScaleY,
    kIOHIDEventFieldScaleZ
};

enum {
    kIOHIDEventFieldVelocityX = IOHIDEventFieldBase(kIOHIDEventTypeVelocity),
    kIOHIDEventFieldVelocityY,
    kIOHIDEventFieldVelocityZ
};

enum {
    kIOHIDEventFieldPointerX = IOHIDEventFieldBase(kIOHIDEventTypePointer),
    kIOHIDEventFieldPointerY,
    kIOHIDEventFieldPointerZ,
    kIOHIDEventFieldPointerButtonMask,
    kIOHIDEventFieldPointerButtonNumber     = kIOHIDEventFieldButtonNumber,
    kIOHIDEventFieldPointerButtonClickCount = kIOHIDEventFieldButtonClickCount,
    kIOHIDEventFieldPointerButtonPressure   = kIOHIDEventFieldButtonPressure
};

enum {
    kIOHIDEventFieldMultiAxisPointerX                   = IOHIDEventFieldBase(kIOHIDEventTypeMultiAxisPointer),
    kIOHIDEventFieldMultiAxisPointerY,
    kIOHIDEventFieldMultiAxisPointerZ,
    kIOHIDEventFieldMultiAxisPointerRx,
    kIOHIDEventFieldMultiAxisPointerRy,
    kIOHIDEventFieldMultiAxisPointerRz,
    kIOHIDEventFieldMultiAxisPointerButtonMask,
    kIOHIDEventFieldMultiAxisPointerButtonNumber        = kIOHIDEventFieldButtonNumber,
    kIOHIDEventFieldMultiAxisPointerButtonClickCount    = kIOHIDEventFieldButtonClickCount,
    kIOHIDEventFieldMultiAxisPointerButtonPressure      = kIOHIDEventFieldButtonPressure
};

/* DEPRECATED: use pointer field */
enum {
    kIOHIDEventFieldMouseX          = kIOHIDEventFieldPointerX,
    kIOHIDEventFieldMouseY          = kIOHIDEventFieldPointerY,
    kIOHIDEventFieldMouseZ          = kIOHIDEventFieldPointerZ,
    kIOHIDEventFieldMouseButtonMask = kIOHIDEventFieldPointerButtonMask,
    kIOHIDEventFieldMouseNumber     = kIOHIDEventFieldPointerButtonNumber,
    kIOHIDEventFieldMouseClickCount = kIOHIDEventFieldPointerButtonClickCount,
    kIOHIDEventFieldMousePressure   = kIOHIDEventFieldPointerButtonPressure
};


/*!
 @typedef IOHIDMotionType
 @abstract Type of Motion event triggered.
 @discussion
 @constant kIOHIDMotionTypeNormal
 @constant kIOHIDMotionTypeShake
 */
enum {
    kIOHIDMotionTypeNormal   = 0,
    kIOHIDMotionTypeShake    = 1,
    kIOHIDMotionTypePath     = 2
};
typedef uint32_t IOHIDMotionType;

/*!
 @typedef IOHIDMotionPath
 @abstract Type of Motion Path event triggered.
 @discussion
 @constant IOHIDMotionPathStart
 @constant IOHIDMotionPathEnd
 */
enum {
    kIOHIDMotionPathStart   = 0,
    kIOHIDMotionPathEnd     = 1,
};
typedef uint32_t IOHIDMotionPath;

// Legacy
enum {
    kIOHIDAccelerometerTypeNormal   = kIOHIDMotionTypeNormal,
    kIOHIDAccelerometerTypeShake    = kIOHIDMotionTypeShake,
    kIOHIDGyroTypeNormal            = kIOHIDMotionTypeNormal,
    kIOHIDGyroTypeShake             = kIOHIDMotionTypeShake,
};

typedef IOHIDMotionType IOHIDAccelerometerType;
typedef IOHIDMotionPath IOHIDAccelerometerSubType;

enum {
    kIOHIDEventFieldAccelerometerX = IOHIDEventFieldBase(kIOHIDEventTypeAccelerometer),
    kIOHIDEventFieldAccelerometerY,
    kIOHIDEventFieldAccelerometerZ,
    kIOHIDEventFieldAccelerometerType,
    kIOHIDEventFieldAccelerometerSubType,
    kIOHIDEventFieldAccelerometerSequence,
};

typedef IOHIDMotionType IOHIDGyroType;
typedef IOHIDMotionPath IOHIDGyroSubType;

enum {
    kIOHIDEventFieldGyroX = IOHIDEventFieldBase(kIOHIDEventTypeGyro),
    kIOHIDEventFieldGyroY,
    kIOHIDEventFieldGyroZ, 
    kIOHIDEventFieldGyroType,
    kIOHIDEventFieldGyroSubType,
    kIOHIDEventFieldGyroSequence
};

typedef IOHIDMotionType IOHIDCompassType;
typedef IOHIDMotionPath IOHIDCompassSubType;

enum {
    kIOHIDEventFieldCompassX = IOHIDEventFieldBase(kIOHIDEventTypeCompass),
    kIOHIDEventFieldCompassY,
    kIOHIDEventFieldCompassZ, 
    kIOHIDEventFieldCompassType,
    kIOHIDEventFieldCompassSubType,
    kIOHIDEventFieldCompassSequence
};

enum {
    kIOHIDEventFieldAmbientLightSensorLevel = IOHIDEventFieldBase(kIOHIDEventTypeAmbientLightSensor),
    kIOHIDEventFieldAmbientLightSensorRawChannel0,
    kIOHIDEventFieldAmbientLightSensorRawChannel1,
    kIOHIDEventFieldAmbientLightSensorRawChannel2,
    kIOHIDEventFieldAmbientLightSensorRawChannel3,
    kIOHIDEventFieldAmbientLightDisplayBrightnessChanged
};

enum {
    kIOHIDEventFieldTemperatureLevel = IOHIDEventFieldBase(kIOHIDEventTypeTemperature)
};

enum {
    kIOHIDEventFieldProximityDetectionMask = IOHIDEventFieldBase(kIOHIDEventTypeProximity),
    kIOHIDEventFieldProximityLevel
};


enum {
    kIOHIDEventFieldOrientationRadius   = IOHIDEventFieldBase(kIOHIDEventTypeOrientation),
    kIOHIDEventFieldOrientationAzimuth,
    kIOHIDEventFieldOrientationAltitude
};

enum {
    kIOHIDEventFieldKeyboardUsagePage = IOHIDEventFieldBase(kIOHIDEventTypeKeyboard),
    kIOHIDEventFieldKeyboardUsage,
    kIOHIDEventFieldKeyboardDown,
    kIOHIDEventFieldKeyboardRepeat
};

enum {
    kIOHIDEventFieldDigitizerX = IOHIDEventFieldBase(kIOHIDEventTypeDigitizer),
    kIOHIDEventFieldDigitizerY,
    kIOHIDEventFieldDigitizerZ,
    kIOHIDEventFieldDigitizerButtonMask,
    kIOHIDEventFieldDigitizerType,
    kIOHIDEventFieldDigitizerIndex,
    kIOHIDEventFieldDigitizerIdentity,
    kIOHIDEventFieldDigitizerEventMask,
    kIOHIDEventFieldDigitizerRange,   
    kIOHIDEventFieldDigitizerTouch,
    kIOHIDEventFieldDigitizerPressure,
    kIOHIDEventFieldDigitizerAuxiliaryPressure, //BarrelPressure
    kIOHIDEventFieldDigitizerTwist,
    kIOHIDEventFieldDigitizerTiltX,
    kIOHIDEventFieldDigitizerTiltY,
    kIOHIDEventFieldDigitizerAltitude,
    kIOHIDEventFieldDigitizerAzimuth,
    kIOHIDEventFieldDigitizerQuality,
    kIOHIDEventFieldDigitizerDensity,
    kIOHIDEventFieldDigitizerIrregularity,
    kIOHIDEventFieldDigitizerMajorRadius,
    kIOHIDEventFieldDigitizerMinorRadius,
    kIOHIDEventFieldDigitizerCollection,
    kIOHIDEventFieldDigitizerCollectionChord,
    kIOHIDEventFieldDigitizerChildEventMask,
    kIOHIDEventFieldDigitizerIsDisplayIntegrated,
    kIOHIDEventFieldDigitizerQualityRadiiAccuracy,
};

enum {
    kIOHIDEventFieldSwipeMask = IOHIDEventFieldBase(kIOHIDEventTypeSwipe),
    kIOHIDEventFieldSwipeMotion,
    kIOHIDEventFieldSwipeProgress,
    kIOHIDEventFieldSwipePositionX,
    kIOHIDEventFieldSwipePositionY,
    kIOHIDEventFieldSwipeFlavor,
};

enum {
    kIOHIDEventFieldNavigationSwipeMask = IOHIDEventFieldBase(kIOHIDEventTypeNavigationSwipe),
    kIOHIDEventFieldNavigationSwipeMotion,
    kIOHIDEventFieldNavigationSwipeProgress,
    kIOHIDEventFieldNavigationSwipePositionX,
    kIOHIDEventFieldNavigationSwipePositionY,
    kIOHIDEventFieldNavagationSwipeFlavor,
};

enum {
    kIOHIDEventFieldDockSwipeMask = IOHIDEventFieldBase(kIOHIDEventTypeDockSwipe),
    kIOHIDEventFieldDockSwipeMotion,
    kIOHIDEventFieldDockSwipeProgress,
    kIOHIDEventFieldDockSwipePositionX,
    kIOHIDEventFieldDockSwipePositionY,
    kIOHIDEventFieldDockSwipeFlavor,
};

enum {
    kIOHIDEventFieldFluidTouchGestureMask = IOHIDEventFieldBase(kIOHIDEventTypeFluidTouchGesture),
    kIOHIDEventFieldFluidTouchGestureMotion,
    kIOHIDEventFieldFluidTouchGestureProgress,
    kIOHIDEventFieldFluidTouchGesturePositionX,
    kIOHIDEventFieldFluidTouchGesturePositionY,
    kIOHIDEventFieldFluidTouchGestureFlavor,
};

enum {
    kIOHIDEventFieldBoundaryScrollMask = IOHIDEventFieldBase(kIOHIDEventTypeBoundaryScroll),
    kIOHIDEventFieldBoundaryScrollMotion,
    kIOHIDEventFieldBoundaryScrollProgress,
    kIOHIDEventFieldBoundaryScrollPositionX,
    kIOHIDEventFieldBoundaryScrollPositionY,
    kIOHIDEventFieldBoundaryScrollFlavor,
};

enum {
    kIOHIDEventFieldProgressEventType = IOHIDEventFieldBase(kIOHIDEventTypeProgress),
    kIOHIDEventFieldProgressLevel,
};

enum {
    kIOHIDEventFieldSymbolicHotKeyValue = IOHIDEventFieldBase(kIOHIDEventTypeSymbolicHotKey),
    kIOHIDEventFieldSymbolicHotKeyIsCGSEvent,
};

/*!
 @typedef IOHIDPowerType
 @abstract Type of Power event triggered.
 @discussion
 @constant kIOHIDPowerTypePower
 @constant kIOHIDPowerTypeCurrent
 @constant kIOHIDPowerTypeVoltage
 */
enum {
    kIOHIDPowerTypePower    = 0,
    kIOHIDPowerTypeCurrent  = 1,
    kIOHIDPowerTypeVoltage  = 2
};
typedef uint32_t IOHIDPowerType;

/*!
 @typedef IOHIDPowerSubType
 @abstract Reserved
 @discussion
 @constant kIOHIDPowerSubTypeNormal
 @constant kIOHIDPowerSubTypeCumulative
 */
enum {
    kIOHIDPowerSubTypeNormal = 0,
    kIOHIDPowerSubTypeCumulative
};
typedef uint32_t IOHIDPowerSubType;

enum {
    kIOHIDEventFieldPowerMeasurement = IOHIDEventFieldBase(kIOHIDEventTypePower),
    kIOHIDEventFieldPowerType,
    kIOHIDEventFieldPowerSubType,
};

/*!
 @typedef IOHIDBiometricEventType
 @abstract Type of biometric event triggered.
 @discussion
 @constant kIOHIDBiometricEventTypeHumanProximity
 @constant kIOHIDBiometricEventTypeHumanTouch
 @constant kIOHIDBiometricEventTypeHumanForce
 */
enum {
    kIOHIDBiometricEventTypeHumanProximity = 0,
    kIOHIDBiometricEventTypeHumanTouch,
    kIOHIDBiometricEventTypeHumanForce
};

typedef uint32_t IOHIDBiometricEventType;

enum {
    kIOHIDEventFieldBiometricEventType = IOHIDEventFieldBase(kIOHIDEventTypeBiometric),
    kIOHIDEventFieldBiometricLevel
};

enum {
    kIOHIDEventFieldLEDMask = IOHIDEventFieldBase(kIOHIDEventTypeLED),
    kIOHIDEventFieldLEDNumber,
    kIOHIDEventFieldLEDState
};


enum {
    kIOHIDUnicodeEncodingTypeUTF8,
    kIOHIDUnicodeEncodingTypeUTF16LE,
    kIOHIDUnicodeEncodingTypeUTF16BE,
    kIOHIDUnicodeEncodingTypeUTF32LE,
    kIOHIDUnicodeEncodingTypeUTF32BE,
};
typedef uint32_t IOHIDUnicodeEncodingType;

/*!
 @typedef IOHIDEventFieldUnicode
 @abstract Event field corresponding the unicode events.
 @discussion The HID Unicode Usage table states that currently only 2-octect are supported,
             but considering that we can easily discern the size of the character field, it's
             possible for us to convey variable length characters provided that the sizes
             are byte aligned
 @constant  kIOHIDEventFieldUnicodeEncoding event field selector representing the unicode encoding
 @constant  kIOHIDEventFieldUnicodeQuality event field selector representing the quality of the character from 0.0 to 1.0
@constant  kIOHIDEventFieldUnicodeLength event field selector representing the length/size
            of the payload in bytes
 @constant  kIOHIDEventFieldPayload event field selector representing the payload of size
            references by kIOHIDEventFieldUnicodeLength
 */

enum {
    kIOHIDEventFieldUnicodeEncoding     = IOHIDEventFieldBase(kIOHIDEventTypeUnicode),
    kIOHIDEventFieldUnicodeQuality,
    kIOHIDEventFieldUnicodeLength,
    kIOHIDEventFieldUnicodePayload
};

enum {
    kIOHIDEventFieldAtmosphericPressureLevel = IOHIDEventFieldBase(kIOHIDEventTypeAtmosphericPressure),
    kIOHIDEventFieldAtmosphericSequence
};

#if IRONSIDE_AVAILABLE // {
enum {
    kIOHIDEventFieldForceBehavior = IOHIDEventFieldBase(kIOHIDEventTypeForce),
    kIOHIDEventFieldForceTransitionProgress,
    kIOHIDEventFieldForceStage,
    kIOHIDEventFieldForceStagePressure, 
    kIOHIDEventFieldForceProgress = kIOHIDEventFieldForceTransitionProgress,
    kIOHIDEventFieldForceLean = kIOHIDEventFieldForceStagePressure,
};
#endif // } IRONSIDE_AVAILABLE

typedef uint32_t IOHIDEventField;

/*!
    @typedef IOHIDSwipeMask
    @abstract Mask detailing the type of swipe detected.
    @discussion
    @constant kIOHIDSwipeUp
    @constant kIOHIDSwipeDown
    @constant kIOHIDSwipeLeft
    @constant kIOHIDSwipeRight
*/
enum {
    kIOHIDSwipeNone             = 0,
    kIOHIDSwipeUp               = 1<<0,
    kIOHIDSwipeDown             = 1<<1,
    kIOHIDSwipeLeft             = 1<<2,
    kIOHIDSwipeRight            = 1<<3,
    kIOHIDScaleExpand           = 1<<4,
    kIOHIDScaleContract         = 1<<5,
    kIOHIDRotateCW              = 1<<6,
    kIOHIDRotateCCW             = 1<<7,
};
typedef uint32_t IOHIDSwipeMask;

/*!
    @typedef IOHIDGestureMotion
    @abstract 
    @constant kIOHIDGestureMotionNone
    @constant kIOHIDGestureMotionHorizontalX
    @constant kIOHIDGestureMotionVerticalY
    @constant kIOHIDGestureMotionScale
    @constant kIOHIDGestureMotionRotate
    @constant kIOHIDGestureMotionTap
    @constant kIOHIDGestureMotionDoubleTap
    @constant kIOHIDGestureMotionFromLeftEdge
    @constant kIOHIDGestureMotionOffLeftEdge
    @constant kIOHIDGestureMotionFromRightEdge
    @constant kIOHIDGestureMotionOffRightEdge
    @constant kIOHIDGestureMotionFromTopEdge
    @constant kIOHIDGestureMotionOffTopEdge
    @constant kIOHIDGestureMotionFromBottomEdge
    @constant kIOHIDGestureMotionOffBottomEdge
*/
enum {
    kIOHIDGestureMotionNone,
    kIOHIDGestureMotionHorizontalX,
    kIOHIDGestureMotionVerticalY,
    kIOHIDGestureMotionScale,
    kIOHIDGestureMotionRotate,
    kIOHIDGestureMotionTap,
    kIOHIDGestureMotionDoubleTap,
    kIOHIDGestureMotionFromLeftEdge,
    kIOHIDGestureMotionOffLeftEdge,
    kIOHIDGestureMotionFromRightEdge,
    kIOHIDGestureMotionOffRightEdge,
    kIOHIDGestureMotionFromTopEdge,
    kIOHIDGestureMotionOffTopEdge,
    kIOHIDGestureMotionFromBottomEdge,
    kIOHIDGestureMotionOffBottomEdge,
};
typedef uint16_t IOHIDGestureMotion;

/*!
    @typedef IOHIDGestureFlavor
    @abstract 
    @constant kIOHIDGestureFlavorNone
    @constant kIOHIDGestureFlavorNotificationCenterPrimary
    @constant kIOHIDGestureFlavorNotificationCenterSecondary
    @constant kIOHIDGestureFlavorDockPrimary
    @constant kIOHIDGestureFlavorDockSecondary
    @constant kIOHIDGestureFlavorNavagationPrimary
    @constant kIOHIDGestureFlavorNavagationSecondary
    @constant kIOHIDGestureFlavorControlCenterPrimary
    @constant kIOHIDGestureFlavorControlCenterSecondary
*/
enum {
    kIOHIDGestureFlavorNone,
    kIOHIDGestureFlavorNotificationCenterPrimary,
    kIOHIDGestureFlavorNotificationCenterSecondary,
    kIOHIDGestureFlavorDockPrimary,
    kIOHIDGestureFlavorDockSecondary,
    kIOHIDGestureFlavorNavagationPrimary,
    kIOHIDGestureFlavorNavagationSecondary,
    kIOHIDGestureFlavorControlCenterPrimary,
    kIOHIDGestureFlavorControlCenterSecondary,
};
typedef uint16_t IOHIDGestureFlavor;

/*!
    @typedef IOHIDProximityDetectionMask
    @abstract Proximity mask detailing the inputs that were detected.
    @discussion
    @constant kIOHIDProximityDetectionLargeBodyContact
    @constant kIOHIDProximityDetectionLargeBodyFarField
    @constant kIOHIDProximityDetectionIrregularObjects
    @constant kIOHIDProximityDetectionEdgeStraddling
    @constant kIOHIDProximityDetectionFlatFingerClasp
    @constant kIOHIDProximityDetectionFingerTouch
    @constant kIOHIDProximityDetectionReceiver
    @constant kIOHIDProximityDetectionSmallObjectsHovering
    @constant kIOHIDProximityDetectionReceiverCrude
    @constant kIOHIDProximityDetectionReceiverMonitoring
*/
enum {
    kIOHIDProximityDetectionLargeBodyContact                = 1<<0,
    kIOHIDProximityDetectionLargeBodyFarField               = 1<<1,
    kIOHIDProximityDetectionIrregularObjects                = 1<<2,
    kIOHIDProximityDetectionEdgeStraddling                  = 1<<3,
    kIOHIDProximityDetectionFlatFingerClasp                 = 1<<4,
    kIOHIDProximityDetectionFingerTouch                     = 1<<5,
    kIOHIDProximityDetectionReceiver                        = 1<<6,
    kIOHIDProximityDetectionSmallObjectsHovering            = 1<<7,
    kIOHIDProximityDetectionReceiverCrude                   = 1<<8,
    kIOHIDProximityDetectionReceiverMonitoring              = 1<<9
};
typedef uint32_t IOHIDProximityDetectionMask;

/*!
    @typedef IOHIDDigitizerType
    @abstract The type of digitizer path initiating an event.
    @constant kIOHIDDigitizerTransducerTypeStylus
    @constant kIOHIDDigitizerTransducerTypePuck
    @constant kIOHIDDigitizerTransducerTypeFinger
    @constant kIOHIDDigitizerTransducerTypeHand
*/
enum {   
    kIOHIDDigitizerTransducerTypeStylus  = 0,
    kIOHIDDigitizerTransducerTypePuck,
    kIOHIDDigitizerTransducerTypeFinger,
    kIOHIDDigitizerTransducerTypeHand
};
typedef uint32_t IOHIDDigitizerTransducerType;

/*!
    @typedef IOHIDDigitizerEventMask
    @abstract Event mask detailing the events being dispatched by a digitizer.
    @discussion It is possible for digitizer events to contain child digitizer events, effectively, behaving as collections.  
    In the collection case, the child event mask field referrence by kIOHIDEventFieldDigitizerChildEventMask will detail the 
    cumulative event state of the child digitizer events.
    <br>
    <b>Please Note:</b>
    If you append a child digitizer event to a parent digitizer event, appropriate state will be transfered on to the parent.
    @constant kIOHIDDigitizerEventRange Issued when the range state has changed.
    @constant kIOHIDDigitizerEventTouch Issued when the touch state has changed.
    @constant kIOHIDDigitizerEventPosition Issued when the position has changed.
    @constant kIOHIDDigitizerEventStop Issued when motion has achieved a state of calculated non-movement.
    @constant kIOHIDDigitizerEventPeak Issues when new maximum values have been detected.
    @constant kIOHIDDigitizerEventIdentity Issued when the identity has changed.
    @constant kIOHIDDigitizerEventAttribute Issued when an attribute has changed.
    @constant kIOHIDDigitizerEventCancel
    @constant kIOHIDDigitizerEventResting
    @constant kIOHIDDigitizerEventFromEdgeFlat Issued when a digitizer approaches from the edge with flattened presentation
    @constant kIOHIDDigitizerEventFromEdgeTip Issued when a digitizer approaches from the edge with standard (i.e. un-flattened) presentation.
    @constant kIOHIDDigitizerEventFromCorner Issued when a digitizer approaches from a corner
    @constant kIOHIDDigitizerEventSwipePending Issued to indicate that an edge swipe is pending 
    @constant kIOHIDDigitizerEventUpSwipe Issued when an up swipe has been detected.
    @constant kIOHIDDigitizerEventDownSwipe Issued when an down swipe has been detected.
    @constant kIOHIDDigitizerEventLeftSwipe Issued when an left swipe has been detected.
    @constant kIOHIDDigitizerEventRightSwipe Issued when an right swipe has been detected.
    @constant kIOHIDDigitizerEventSwipeMask Mask used to gather swipe events.
*/
enum {
    kIOHIDDigitizerEventRange                               = 1<<0,
    kIOHIDDigitizerEventTouch                               = 1<<1,
    kIOHIDDigitizerEventPosition                            = 1<<2,
    kIOHIDDigitizerEventStop                                = 1<<3,
    kIOHIDDigitizerEventPeak                                = 1<<4,
    kIOHIDDigitizerEventIdentity                            = 1<<5,
    kIOHIDDigitizerEventAttribute                           = 1<<6,
    kIOHIDDigitizerEventCancel                              = 1<<7,
    kIOHIDDigitizerEventStart                               = 1<<8,
    kIOHIDDigitizerEventResting                             = 1<<9,
    kIOHIDDigitizerEventFromEdgeFlat                        = 1<<10,
    kIOHIDDigitizerEventFromEdgeTip                         = 1<<11,
    kIOHIDDigitizerEventFromCorner                          = 1<<12,
    kIOHIDDigitizerEventSwipePending                        = 1<<13,
    kIOHIDDigitizerEventSwipeUp                             = 1<<24,
    kIOHIDDigitizerEventSwipeDown                           = 1<<25,
    kIOHIDDigitizerEventSwipeLeft                           = 1<<26,
    kIOHIDDigitizerEventSwipeRight                          = 1<<27,
    kIOHIDDigitizerEventSwipeMask                           = 0xFF<<24,
};
typedef uint32_t IOHIDDigitizerEventMask;

enum {
    kIOHIDEventOptionNone                                   = 0,
    kIOHIDEventOptionIsAbsolute                             = 1<<0,
    kIOHIDEventOptionIsCollection                           = 1<<1,
    kIOHIDEventOptionIsPixelUnits                           = 1<<2,
    kIOHIDEventOptionIsCenterOrigin                         = 1<<3,
    kIOHIDEventOptionIsBuiltIn                              = 1<<4,

    // misspellings
    kIOHIDEventOptionPixelUnits                             = kIOHIDEventOptionIsPixelUnits,
};
typedef uint32_t IOHIDEventOptionBits;

enum {
    kIOHIDEventPhaseUndefined                               = 0,
    kIOHIDEventPhaseBegan                                   = 1<<0,
    kIOHIDEventPhaseChanged                                 = 1<<1,
    kIOHIDEventPhaseEnded                                   = 1<<2,
    kIOHIDEventPhaseCancelled                               = 1<<3,
    kIOHIDEventPhaseMayBegin                                = 1<<7,
    kIOHIDEventEventPhaseMask                               = 0xFF,
    kIOHIDEventEventOptionPhaseShift                        = 24,
};
typedef uint16_t IOHIDEventPhaseBits;

/*!
 @typedef IOHIDSymbolicHotKey
 @abstract Enumerted values for sending symbolic hot key events.
 @constant kIOHIDSymbolicHotKeyDictionaryApp    This will get translated into a kCGSDictionaryAppHotKey by CG.
 @constant kIOHIDSymbolicHotKeyIronwoodApp      This will get translated into a kCGSIronwoodHotKey by CG.
 @constant kIOHIDSymbolicHotKeyDictationApp     This will get translated into a kCGSDictationHotKey by CG.
 @constant kIOHIDSymbolicHotKeyOptionIsCGSHotKey
                                                This is an option flag to denote that the SymbolicHotKey value is
                                                actually from the enumeration in CGSHotKeys.h.
 */
enum {
    kIOHIDSymbolicHotKeyUndefined,
    kIOHIDSymbolicHotKeyDictionaryApp,
    kIOHIDSymbolicHotKeyIronwoodApp,
    kIOHIDSymbolicHotKeyDictationApp,
    
    // for kIOHIDSymbolicHotKeyOptionIsCGSHotKey, see IOHIDFamily/IOHIDEventData.h
};
typedef uint32_t IOHIDSymbolicHotKeyValue;


enum {
    kIOHIDEventSenderIDUndefined                            = 0x0000000000000000LL,
};
typedef uint64_t IOHIDEventSenderID; // must be the same size as that returned from IORegistryEntry::getRegistryEntryID

#ifndef KERNEL
/*!
    @typedef IOHIDFloat
*/
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif
/*!
    @typedef IOHID3DPoint
*/
typedef struct _IOHID3DPoint {
    IOHIDFloat  x;
    IOHIDFloat  y;
    IOHIDFloat  z;
} IOHID3DPoint; 
#endif

#endif /* _IOKIT_HID_IOHIDEVENTTYPES_H } */
