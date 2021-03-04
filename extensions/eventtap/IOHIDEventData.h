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


#include "IOHIDEventTypes.h"

#define IOHIDEVENT_BASE         \
    uint32_t        size;       \
    IOHIDEventType  type;       \
    uint64_t        timestamp;  \
    uint32_t        options

#define IOHIDAXISEVENT_BASE     \
    struct {                    \
        IOFixed x;              \
        IOFixed y;              \
        IOFixed z;              \
    } position


// NOTE: original Apple source had "struct IOHIDEventData" instead of typedef
typedef struct _IOHIDEventData {
    IOHIDEVENT_BASE;
} IOHIDEventData;

typedef struct _IOHIDVendorDefinedEventData {
    IOHIDEVENT_BASE;
    uint16_t        usagePage;
    uint16_t        usage;
    uint32_t        version;
    uint32_t        length;
    uint8_t         data[0];
} IOHIDVendorDefinedEventData;

// NOTE: these are additional option flags used with digitizer event
enum {
    kIOHIDTransducerRange       = 0x00010000,
    kIOHIDTransducerTouch       = 0x00020000,
    kIOHIDTransducerInvert      = 0x00040000,
};

enum {
    kIOHIDDigitizerOrientationTypeTilt = 0,
    kIOHIDDigitizerOrientationTypePolar,
    kIOHIDDigitizerOrientationTypeQuality
};
typedef uint8_t IOHIDDigitizerOrientationType;


#define IOHIDBUTTONEVENT_BASE           \
    struct {                            \
        uint32_t        buttonMask;     \
        IOFixed         pressure;       \
        uint8_t         buttonNumber;   \
        uint8_t         clickState;     \
    } button

typedef struct _IOHIDButtonEventData {
    IOHIDEVENT_BASE;
    IOHIDBUTTONEVENT_BASE;
} IOHIDButtonEventData;

typedef struct _IOHIDMouseEventData {
    IOHIDEVENT_BASE;
    IOHIDAXISEVENT_BASE;
    IOHIDBUTTONEVENT_BASE;
} IOHIDMouseEventData;

typedef struct _IOHIDDigitizerEventData {
	IOHIDEVENT_BASE;                            // options = kIOHIDTransducerRange, kHIDTransducerTouch, kHIDTransducerInvert
    IOHIDAXISEVENT_BASE;
	
    uint32_t        transducerIndex;   
    uint32_t        transducerType;				// could overload this to include that both the hand and finger id.
    uint32_t        identity;                   // Specifies a unique ID of the current transducer action.
    uint32_t        eventMask;                  // the type of event that has occurred: range, touch, position (IOHIDDigitizerEventMask?)
    uint32_t        childEventMask;             // CHILD: the type of event that has occurred: range, touch, position
    
    uint32_t        buttonMask;                 // Bit field representing the current button state
	// Pressure field are assumed to be scaled from 0.0 to 1.0
    IOFixed         tipPressure;                // Force exerted against the digitizer surface by the transducer.
    IOFixed         barrelPressure;             // Force exerted directly by the user on a transducer sensor.
    
    IOFixed         twist;                      // Specifies the clockwise rotation of the cursor around its own major axis.  Unsure it the device should declare units via properties or event.  My first inclination is force degrees as the is the unit already expected by AppKit, Carbon and OpenGL.
    uint32_t        orientationType;            // Specifies the orientation type used by the transducer.
    union {
        struct {                                // X Tilt and Y Tilt are used together to specify the tilt away from normal of a digitizer transducer. In its normal position, the values of X Tilt and Y Tilt for a transducer are both zero.
            IOFixed     x;                      // This quantity is used in conjunction with Y Tilt to represent the tilt away from normal of a transducer, such as a stylus. The X Tilt value represents the plane angle between the Y-Z plane and the plane containing the transducer axis and the Y axis. A positive X Tilt is to the right. 
            IOFixed     y;                      // This value represents the angle between the X-Z and transducer-X planes. A positive Y Tilt is toward the user.
        } tilt;
        struct {                                // X Tilt and Y Tilt are used together to specify the tilt away from normal of a digitizer transducer. In its normal position, the values of X Tilt and Y Tilt for a transducer are both zero.
            IOFixed  altitude;                  //The angle with the X-Y plane though a signed, semicicular range.  Positive values specify an angle downward and toward the positive Z axis. 
            IOFixed  azimuth;                   // Specifies the counter clockwise rotation of the cursor around the Z axis though a full circular range.
        } polar;
        struct {
            IOFixed  quality;                    // If set, indicates that the transducer is sensed to be in a relatively noise-free region of digitizing.
            IOFixed  density;
            IOFixed  irregularity;
            IOFixed  majorRadius;                // units in mm
            IOFixed  minorRadius;                // units in mm
        } quality;
    } orientation;
} IOHIDDigitizerEventData;

typedef struct _IOHIDAxisEventData {
    IOHIDEVENT_BASE;                            // options = kHIDAxisRelative
    IOHIDAXISEVENT_BASE;
} IOHIDAxisEventData, IOHIDTranslationData, IOHIDRotationEventData, IOHIDScrollEventData, IOHIDScaleEventData, IOHIDVelocityData, IOHIDOrientationEventData;

typedef struct _IOHIDSwipeEventData {
    IOHIDEVENT_BASE;                            
    IOHIDSwipeMask swipeMask;
} IOHIDSwipeEventData;

/*!
 @typedef    IOHIDSystemQueueElement
 @abstract   Memory structure defining the layout of each event queue element
 @discussion The IOHIDEventQueueElement represents a portion of mememory in the
 new IOHIDEventQueue.  It is possible that a event queue element
 can contain multiple interpretations of a given event.  The first
 event is always considered the primary event.
 @field      version     Version of the event queue element
 @field      size        Size, in bytes, of this particular event queue element
 @field      timeStamp   Time at which event was dispatched
 @field      deviceID    ID of the sending device
 @field      options     Options for further developement
 @field      eventCount  The number of events contained in this transaction
 @field      events      Begining offset of contiguous mememory that contains the
 pertinent event data
 */
typedef struct _IOHIDSystemQueueElement {
    uint64_t        timeStamp;
    uint64_t        deviceID;
    uint32_t        options;
    uint32_t        eventCount;
    IOHIDEventData  events[];
} IOHIDSystemQueueElement;
