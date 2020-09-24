/*
 *  TouchEvents.c
 *  TouchSynthesis
 *
 *  Created by Nathan Vander Wilt on 1/13/10.
 *  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
 *
 */

#include "TouchEvents.h"

#include "IOHIDEventData.h"

const CFStringRef kTLInfoKeyDeviceID = CFSTR("deviceID");
const CFStringRef kTLInfoKeyTimestamp = CFSTR("timestamp");
const CFStringRef kTLInfoKeyGestureSubtype = CFSTR("gestureSubtype");
const CFStringRef kTLInfoKeyGesturePhase = CFSTR("gesturePhase");
const CFStringRef kTLInfoKeyMagnification = CFSTR("magnification");
const CFStringRef kTLInfoKeyRotation = CFSTR("rotation");
const CFStringRef kTLInfoKeySwipeDirection = CFSTR("swipeDirection");
const CFStringRef kTLInfoKeyNextSubtype = CFSTR("nextSubtype");


const CFStringRef kTLEventKeyType = CFSTR("type");
const CFStringRef kTLEventKeyTimestamp = CFSTR("timestamp");
const CFStringRef kTLEventKeyOptions = CFSTR("options");

const CFStringRef kTLEventKeyPositionX = CFSTR("position.x");
const CFStringRef kTLEventKeyPositionY = CFSTR("position.y");
const CFStringRef kTLEventKeyPositionZ = CFSTR("position.z");

const CFStringRef kTLEventKeyTransducerIndex = CFSTR("transducerIndex");
const CFStringRef kTLEventKeyTransducerType = CFSTR("transducerType");
const CFStringRef kTLEventKeyIdentity = CFSTR("identity");
const CFStringRef kTLEventKeyEventMask = CFSTR("eventMask");

const CFStringRef kTLEventKeyButtonMask = CFSTR("buttonMask");
const CFStringRef kTLEventKeyTipPressure = CFSTR("tipPressure");
const CFStringRef kTLEventKeyBarrelPressure = CFSTR("barrelPressure");
const CFStringRef kTLEventKeyTwist = CFSTR("twist");

const CFStringRef kTLEventKeyQuality = CFSTR("quality");
const CFStringRef kTLEventKeyDensity = CFSTR("density");
const CFStringRef kTLEventKeyIrregularity = CFSTR("irregularity");
const CFStringRef kTLEventKeyMajorRadius = CFSTR("majorRadius");
const CFStringRef kTLEventKeyMinorRadius = CFSTR("minorRadius");


static inline IOFixed tl_float2fixed(double f) { return (IOFixed)(f * 65536.0); }

static inline uint64_t tl_uptime() {
	AbsoluteTime uptimeAbs = AbsoluteToNanoseconds(UpTime());
	return ((uint64_t)uptimeAbs.hi << 32) + uptimeAbs.lo;
}

static inline void setVendorData(IOHIDVendorDefinedEventData* vd, const void* data) {
	memmove(vd->data, data, vd->length);
}


static void appendHeader(CFMutableDataRef data, uint8_t field, uint8_t type, uint16_t count) {
	// serialize header
	uint16_t swappedCount = CFSwapInt16HostToBig(count);
	CFDataAppendBytes(data, (UInt8*)&swappedCount, sizeof(uint16_t));
	CFDataAppendBytes(data, &type, 1);
	CFDataAppendBytes(data, &field, 1);
}

static void appendField(CFMutableDataRef data, uint8_t field, uint8_t type, uint16_t count, void* fieldData) {
	appendHeader(data, field, type, count);
	switch (type) {
		case 0x00:	// uint64_t as UnsignedWide
			for (uint16_t i = 0; i < count; ++i) {
				uint64_t val = ((uint64_t*)fieldData)[i];
				uint32_t loVal = (uint32_t)val;
				uint32_t swappedLoVal = CFSwapInt32HostToBig(loVal);
				CFDataAppendBytes(data, (UInt8*)&swappedLoVal, sizeof(uint32_t));
				uint32_t hiVal = (uint32_t)(val >> 32);
				uint32_t swappedHiVal = CFSwapInt32HostToBig(hiVal);
				CFDataAppendBytes(data, (UInt8*)&swappedHiVal, sizeof(uint32_t));
			}
			break;
		case 0x10:	// uint8_t
			for (uint16_t i = 0; i < count; ++i) {
				uint8_t val = ((uint8_t*)fieldData)[i];
				CFDataAppendBytes(data, &val, 1);
			}
			break;
		case 0x40:
			for (uint16_t i = 0; i < count; ++i) {
				uint32_t val = ((uint32_t*)fieldData)[i];
				uint32_t swappedVal = CFSwapInt32HostToBig(val);
				CFDataAppendBytes(data, (UInt8*)&swappedVal, sizeof(uint32_t));
			}
			break;
		case 0xC0:
			for (uint16_t i = 0; i < count; ++i) {
				Float32 val = ((Float32*)fieldData)[i];
				CFSwappedFloat32 swappedVal = CFConvertFloat32HostToSwapped(val);
				CFDataAppendBytes(data, (UInt8*)&swappedVal, sizeof(CFSwappedFloat32));
			}
			break;
	}
}

static void appendIntegerField(CFMutableDataRef data, uint8_t field, uint32_t value) {
	(void)appendField;
	appendHeader(data, field, 0x40, 1);
	uint32_t swappedValue = CFSwapInt32HostToBig(value);
	CFDataAppendBytes(data, (UInt8*)&swappedValue, sizeof(uint32_t));
}

static void appendFloatField(CFMutableDataRef data, uint8_t field, Float32 value) {
	appendHeader(data, field, 0xC0, 1);
	CFSwappedFloat32 swappedValue = CFConvertFloat32HostToSwapped(value);
	CFDataAppendBytes(data, (UInt8*)&swappedValue, sizeof(CFSwappedFloat32));
}

static void fillOutBase(CFDictionaryRef info, IOHIDEventData* event) {
	CFNumberRef val;
	if ((val = CFDictionaryGetValue(info, kTLEventKeyTimestamp))) {
		CFNumberGetValue(val, kCFNumberSInt64Type, &event->timestamp);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyOptions))) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &event->options);
	}
}

static void fillOutDigitizer(CFDictionaryRef info, IOHIDDigitizerEventData* event) {
	event->size = (uint32_t)sizeof(IOHIDDigitizerEventData);
	event->type = kIOHIDEventTypeDigitizer;
	CFNumberRef val;
	double d;
	if ((val = CFDictionaryGetValue(info, kTLEventKeyPositionX))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->position.x = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyPositionY))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->position.y = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyPositionZ))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->position.z = tl_float2fixed(d);
	}
	
	if ((val = CFDictionaryGetValue(info, kTLEventKeyTransducerIndex))) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &event->transducerIndex);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyTransducerType))) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &event->transducerType);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyIdentity))) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &event->identity);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyEventMask))) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &event->eventMask);
	}
	
	if ((val = CFDictionaryGetValue(info, kTLEventKeyButtonMask))) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &event->buttonMask);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyTipPressure))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->tipPressure = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyBarrelPressure))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->barrelPressure = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyTwist))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->twist = tl_float2fixed(d);
	}
	
	event->orientationType = kIOHIDDigitizerOrientationTypeQuality;
	if ((val = CFDictionaryGetValue(info, kTLEventKeyQuality))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->orientation.quality.quality = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyDensity))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->orientation.quality.density = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyIrregularity))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->orientation.quality.irregularity = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyMajorRadius))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->orientation.quality.majorRadius = tl_float2fixed(d);
	}
	if ((val = CFDictionaryGetValue(info, kTLEventKeyMinorRadius))) {
		CFNumberGetValue(val, kCFNumberDoubleType, &d);
		event->orientation.quality.minorRadius = tl_float2fixed(d);
	}
}

CGEventRef tl_CGEventCreateFromGesture(CFDictionaryRef info, CFArrayRef touches) {
	assert(info != NULL);
	assert(touches != NULL);
	typedef struct {
		uint32_t count;
		SInt64 sumX;
		SInt64 sumY;
		SInt64 sumZ;
	} AvgPosition;
	AvgPosition avgTouch = {};
	AvgPosition avgRange = {};
	AvgPosition avgOther = {};
	CFNumberRef val;
	
	uint64_t timestamp;
	val = CFDictionaryGetValue(info, kTLInfoKeyTimestamp);
	if (val) {
		CFNumberGetValue(val, kCFNumberSInt64Type, &timestamp);
	}
	else {
		timestamp = tl_uptime();
	}
	
	IOHIDDigitizerEventData parent = {};
	parent.size = (uint32_t)sizeof(IOHIDDigitizerEventData);
	parent.type = kIOHIDEventTypeDigitizer;
	parent.timestamp = timestamp;
	parent.options = kIOHIDEventOptionIsCollection;
	parent.transducerType = kIOHIDDigitizerTransducerTypeHand;
	
	CFMutableDataRef serializedTouches = CFDataCreateMutable(kCFAllocatorDefault, 0);
	CFIndex numTouches = CFArrayGetCount(touches);
	for (CFIndex touchIdx = 0; touchIdx < numTouches; ++touchIdx) {
		CFDictionaryRef touchInfo = CFArrayGetValueAtIndex(touches, touchIdx);
		CFNumberRef typeVal = CFDictionaryGetValue(touchInfo, kTLEventKeyType);
		if (!typeVal) continue;
		
		int32_t type;
		CFNumberGetValue(typeVal, kCFNumberSInt32Type, &type);
		assert(type == kIOHIDEventTypeDigitizer);	// only digitizer events currently supported
		
		IOHIDDigitizerEventData touch = {};
		fillOutBase(touchInfo, (IOHIDEventData*)&touch);
		fillOutDigitizer(touchInfo, &touch);
		CFDataAppendBytes(serializedTouches, (UInt8*)&touch, touch.size);
		
		if (touch.identity) parent.options |= touch.options;
		parent.childEventMask |= touch.eventMask;
		if (touch.options & kIOHIDTransducerTouch) {
			++avgTouch.count;
			avgTouch.sumX += touch.position.x;
			avgTouch.sumY += touch.position.y;
			avgTouch.sumZ += touch.position.z;
		}
		else if (touch.options & kIOHIDTransducerRange) {
			++avgRange.count;
			avgRange.sumX += touch.position.x;
			avgRange.sumY += touch.position.y;
			avgRange.sumZ += touch.position.z;
		}
		else {
			++avgOther.count;
			avgOther.sumX += touch.position.x;
			avgOther.sumY += touch.position.y;
			avgOther.sumZ += touch.position.z;
		}
	}
	
	// calculate parent position
	if (avgTouch.count) {
		parent.position.x = (IOFixed)(avgTouch.sumX / avgTouch.count);
		parent.position.y = (IOFixed)(avgTouch.sumY / avgTouch.count);
		parent.position.z = (IOFixed)(avgTouch.sumZ / avgTouch.count);
	}
	else if (avgRange.count) {
		parent.position.x = (IOFixed)(avgRange.sumX / avgRange.count);
		parent.position.y = (IOFixed)(avgRange.sumY / avgRange.count);
		parent.position.z = (IOFixed)(avgRange.sumZ / avgRange.count);
	}
	else if (avgOther.count) {
		parent.position.x = (IOFixed)(avgOther.sumX / avgOther.count);
		parent.position.y = (IOFixed)(avgOther.sumY / avgOther.count);
		parent.position.z = (IOFixed)(avgOther.sumZ / avgOther.count);
	}
	
	// create vendor token
	uint64_t deviceID = 0;
	val = CFDictionaryGetValue(info, kTLInfoKeyDeviceID);
	if (val) {
		CFNumberGetValue(val, kCFNumberSInt64Type, &deviceID);
	}
	UInt8 vendorPayload[40] = {};
	*(uint64_t*)vendorPayload = CFSwapInt64HostToLittle(deviceID);
	const size_t vendorPayloadLen = sizeof(vendorPayload);
	const size_t vendorDataSize = sizeof(IOHIDVendorDefinedEventData) + vendorPayloadLen;
	IOHIDVendorDefinedEventData* vendorData = malloc(vendorDataSize);
	vendorData->size = (uint32_t)vendorDataSize;
	vendorData->type = kIOHIDEventTypeVendorDefined;
	vendorData->usagePage = 0xFF00;
	vendorData->usage = 0x1777;
	vendorData->version = 1;
	vendorData->length = (uint32_t)vendorPayloadLen;
	setVendorData(vendorData, vendorPayload);
	
	// create base event
	CGEventRef protoEvent = CGEventCreate(NULL);
	CGEventSetType(protoEvent, 29);		// NSEventTypeGesture
	CGEventSetFlags(protoEvent, 256);	// magic
	CGEventSetTimestamp(protoEvent, timestamp);
	
	// serialize base event
	CFDataRef baseData = CGEventCreateData(kCFAllocatorDefault, protoEvent);
	CFRelease(protoEvent);
	CFMutableDataRef gestureData = CFDataCreateMutableCopy(kCFAllocatorDefault, 0, baseData);
	CFRelease(baseData);
	
	// remove gesture fields CGEvent has added before the missing event data (it expects to find them after)
	if (CFDataGetLength(gestureData) >= 24) {
		CFDataDeleteBytes(gestureData, CFRangeMake(CFDataGetLength(gestureData) - 24, 24));
	}
	
	// serialize CGEvent field header for IOHID event queue
	uint16_t totalSize = (sizeof(IOHIDSystemQueueElement) + vendorDataSize +
						  (numTouches + 1) * sizeof(IOHIDDigitizerEventData));
	uint16_t swappedTotalSize = CFSwapInt16HostToBig((uint16_t)totalSize);
	CFDataAppendBytes(gestureData, (UInt8*)&swappedTotalSize, 2);
	CFDataAppendBytes(gestureData, (UInt8[]){0x10, 0x6D}, 2);
	
	// serialize event queue collection header
	IOHIDSystemQueueElement queueElement = {};
	queueElement.timeStamp = timestamp;
	queueElement.options = parent.options;
	queueElement.eventCount = (uint32_t)numTouches + 2;
	CFDataAppendBytes(gestureData, (UInt8*)&queueElement, sizeof(queueElement));
	
	// serialize touch event data
	CFDataAppendBytes(gestureData, (UInt8*)&parent, parent.size);
	CFDataAppendBytes(gestureData, CFDataGetBytePtr(serializedTouches), CFDataGetLength(serializedTouches));
	CFRelease(serializedTouches);
	
	// serialize vendor data
	CFDataAppendBytes(gestureData, (UInt8*)vendorData, vendorDataSize);
	free(vendorData);
	
	// serialize gesture event fields
	int32_t gestureSubtype = kTLInfoSubtypeGesture;
	val = CFDictionaryGetValue(info, kTLInfoKeyGestureSubtype);
	if (val) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &gestureSubtype);
	}
	appendIntegerField(gestureData, 0x6E, gestureSubtype);
	appendIntegerField(gestureData, 0x6F, 0);	// magic
	appendIntegerField(gestureData, 0x70, 0);	// magic
	
	int32_t gesturePhase = 0;      // c.f. IOHIDEventPhaseBits
	val = CFDictionaryGetValue(info, kTLInfoKeyGesturePhase);
	if (val) {
		CFNumberGetValue(val, kCFNumberSInt32Type, &gesturePhase);
	}
	appendIntegerField(gestureData, 0x84, gesturePhase);
	appendIntegerField(gestureData, 0x85, 0);	// magic?
   
   
	if (gestureSubtype == kTLInfoSubtypeMagnify) {
		Float32 magnification = 0.0f;
		val = CFDictionaryGetValue(info, kTLInfoKeyMagnification);
		if (val) {
			CFNumberGetValue(val, kCFNumberFloat32Type, &magnification);
		}
		appendFloatField(gestureData, 0x71, magnification);
	}
	else if (gestureSubtype == kTLInfoSubtypeRotate) {
		Float32 rotation = 0.0f;
		val = CFDictionaryGetValue(info, kTLInfoKeyRotation);
		if (val) {
			CFNumberGetValue(val, kCFNumberFloat32Type, &rotation);
		}
		appendFloatField(gestureData, 0x72, rotation);
	}
	else if (gestureSubtype == kTLInfoSubtypeSwipe) {
		int32_t swipeDirection = 0;
		val = CFDictionaryGetValue(info, kTLInfoKeySwipeDirection);
		if (val) {
			CFNumberGetValue(val, kCFNumberSInt32Type, &swipeDirection);
		}
		appendIntegerField(gestureData, 0x73, swipeDirection);
	}
	else if (gestureSubtype == kTLInfoSubtypeBeginGesture ||
			 gestureSubtype == kTLInfoSubtypeEndGesture)
	{
		int32_t nextSubtype = 0;
		val = CFDictionaryGetValue(info, kTLInfoKeyNextSubtype);
		if (val) {
			CFNumberGetValue(val, kCFNumberSInt32Type, &nextSubtype);
		}
		appendIntegerField(gestureData, 0x75, nextSubtype);
	}
	
	appendFloatField(gestureData, 0x8B, 0.0f);		// magic?
	appendFloatField(gestureData, 0x8C, 0.0f);		// magic?
	
	CGEventRef synthEvent = CGEventCreateFromData(kCFAllocatorDefault, gestureData);
	CFRelease(gestureData);
	return synthEvent;
}
