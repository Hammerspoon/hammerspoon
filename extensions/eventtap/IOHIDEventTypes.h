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
#define _IOKIT_HID_IOHIDEVENTTYPES_H

#include <IOKit/IOTypes.h>

#define IOHIDEventTypeMask(type) (1<<type)
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
    @constant kIOHIDEventTypeTranslation
    @constant kIOHIDEventTypeRotation
    @constant kIOHIDEventTypeScroll
    @constant kIOHIDEventTypeScale
    @constant kIOHIDEventTypeVelocity
    @constant kIOHIDEventTypeOrientation
    @constant kIOHIDEventTypeKeyboard 
    @constant kIOHIDEventTypeDigitizer
    @constant kIOHIDEventTypeAmbientLightSensor
    @constant kIOHIDEventTypeAccelerometer
    @constant kIOHIDEventTypeProximity
    @constant kIOHIDEventTypeTemperature
    @constant kIOHIDEventTypeMouse
    @constant kIOHIDEventTypeProgress
    @constant kIOHIDEventTypeSwipe
*/
enum {
    kIOHIDEventTypeNULL,
    kIOHIDEventTypeVendorDefined,
    kIOHIDEventTypeButton,
    kIOHIDEventTypeKeyboard, 
    kIOHIDEventTypeTranslation,
    kIOHIDEventTypeRotation,
    kIOHIDEventTypeScroll,
    kIOHIDEventTypeScale,
    kIOHIDEventTypeZoom,
    kIOHIDEventTypeVelocity,
    kIOHIDEventTypeOrientation,
    kIOHIDEventTypeDigitizer,
    kIOHIDEventTypeAmbientLightSensor,
    kIOHIDEventTypeAccelerometer,
    kIOHIDEventTypeProximity,
    kIOHIDEventTypeTemperature,
    kIOHIDEventTypeSwipe,
    kIOHIDEventTypeMouse,
    kIOHIDEventTypeProgress,
    kIOHIDEventTypeCount
};
typedef uint32_t IOHIDEventType;

/*!
	@typedef IOHIDAccelerometerType
	@abstract Type of accelerometer event triggered.
    @discussion
	@constant kIOHIDAccelerometerTypeNormal
	@constant kIOHIDAccelerometerTypeShake
*/
enum {
    kIOHIDAccelerometerTypeNormal   = 0,
    kIOHIDAccelerometerTypeShake    = 1
};
typedef uint32_t IOHIDAccelerometerType;

/*!
	@typedef IOHIDSwipeMask
	@abstract Mask detailing the type of swipe detected.
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
*/
enum {
    kIOHIDSwipeUp                             = 0x00000001,
    kIOHIDSwipeDown                           = 0x00000002,
    kIOHIDSwipeLeft                           = 0x00000004,
    kIOHIDSwipeRight                          = 0x00000008,
};
typedef uint32_t IOHIDSwipeMask;


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
*/
enum {
    kIOHIDProximityDetectionLargeBodyContact                = 0x0001,
    kIOHIDProximityDetectionLargeBodyFarField               = 0x0002,
    kIOHIDProximityDetectionIrregularObjects                = 0x0004,
    kIOHIDProximityDetectionEdgeStraddling                  = 0x0008,
    kIOHIDProximityDetectionFlatFingerClasp                 = 0x0010,
    kIOHIDProximityDetectionFingerTouch                     = 0x0020,
    kIOHIDProximityDetectionReceiver                        = 0x0040,
    kIOHIDProximityDetectionSmallObjectsHovering            = 0x0080,
    kIOHIDProximityDetectionReceiverCrude                   = 0x0100
};
typedef uint32_t IOHIDProximityDetectionMask;

/*!
	@typedef IOHIDDigitizerType
	@abstract The type of digitizer path initiating an event.
    @discussion The IOHIDDigitizerType usually corresponds to the Logical Collection usage defined in Digitizer Usage Page (0x0d) of the USB HID Usage Tables.
	@constant kIOHIDDigitizerTypeStylus
    @constant kIOHIDDigitizerTypePuck
    @constant kIOHIDDigitizerTypeFinger
*/
enum {   
    kIOHIDDigitizerTransducerTypeStylus  = 0x20,
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
    @constant kIOHIDDigitizerEventUpSwipe Issued when an up swipe has been detected.
    @constant kIOHIDDigitizerEventDownSwipe Issued when an down swipe has been detected.
    @constant kIOHIDDigitizerEventLeftSwipe Issued when an left swipe has been detected.
    @constant kIOHIDDigitizerEventRightSwipe Issued when an right swipe has been detected.
    @constant kIOHIDDigitizerEventSwipeMask Mask used to gather swipe events.
*/
enum {
    kIOHIDDigitizerEventRange                               = 0x00000001,
    kIOHIDDigitizerEventTouch                               = 0x00000002,
    kIOHIDDigitizerEventPosition                            = 0x00000004,
    kIOHIDDigitizerEventStop                                = 0x00000008,
    kIOHIDDigitizerEventPeak                                = 0x00000010,
    kIOHIDDigitizerEventIdentity                            = 0x00000020,
    kIOHIDDigitizerEventAttribute                           = 0x00000040,
    kIOHIDDigitizerEventCancel                              = 0x00000080,
    kIOHIDDigitizerEventStart                               = 0x00000100,
    kIOHIDDigitizerEventResting                             = 0x00000200,
    kIOHIDDigitizerEventSwipeUp                             = 0x01000000,
    kIOHIDDigitizerEventSwipeDown                           = 0x02000000,
    kIOHIDDigitizerEventSwipeLeft                           = 0x04000000,
    kIOHIDDigitizerEventSwipeRight                          = 0x08000000,
    kIOHIDDigitizerEventSwipeMask                           = 0xFF000000,
};
typedef uint32_t IOHIDDigitizerEventMask;

enum {
    kIOHIDEventOptionIsAbsolute                             = 0x00000001,
    kIOHIDEventOptionIsCollection                           = 0x00000002,
    kIOHIDEventOptionPixelUnits                             = 0x00000004
};
typedef uint32_t IOHIDEventOptionBits;

#endif /* _IOKIT_HID_IOHIDEVENTTYPES_H */
