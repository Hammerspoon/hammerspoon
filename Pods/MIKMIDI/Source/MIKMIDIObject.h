//
//  MIKMIDIObject.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/8/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIObject is the base class for all of MIKMIDI's Objective-C wrapper classes for CoreMIDI classes.
 *  It corresponds to MIDIObject in CoreMIDI.
 *
 *  MIKMIDIObject is essentially an "abstract" base class, although it does implement several methods common
 *  to all MIDI objects.
 */
@interface MIKMIDIObject : NSObject

/**
 *  Convenience method for creating a new MIKMIDIObject instance. Returns an instance of a
 *  concrete subclass of MIKMIDIObject (e.g. MIKMIDIDevice, MIKMIDIEntity, 
 *  MIKMIDISource/DestinationEndpoint) depending on the type of the object passed into it.
 *
 *  @param objectRef A CoreMIDI MIDIObjectRef.
 *
 *  @return An instance of the appropriate subclass of MIKMIDIObject.
 */
+ (nullable instancetype)MIDIObjectWithObjectRef:(MIDIObjectRef)objectRef; // Returns a subclass of MIKMIDIObject (device, entity, or endpoint)

/**
 *  Creates and initializes an MIKMIDIObject instance. Returns an instance of a
 *  concrete subclass of MIKMIDIObject (e.g. MIKMIDIDevice, MIKMIDIEntity,
 *  MIKMIDISource/DestinationEndpoint) depending on the type of the object passed into it.
 *
 *  @param objectRef A CoreMIDI MIDIObjectRef.
 *
 *  @return An instance of the appropriate subclass of MIKMIDIObject.
 */
- (nullable instancetype)initWithObjectRef:(MIDIObjectRef)objectRef;

/**
 *  Used to get a dictionary containing key/value pairs corresponding to
 *  the properties returned by CoreMIDI's MIDIObjectGetProperties() function.
 *
 *  For a list of possible keys, see the "Property name constants" section of
 *  CoreMIDI/MIDIServices.h.
 *
 *  @return An NSDictionary containing various properties of the receiver. See
 */
- (NSDictionary *)propertiesDictionary;

/**
 *  The CoreMIDI MIDIObjectRef which the receiver wraps.
 */
@property (nonatomic, readonly) MIDIObjectRef objectRef;

/**
 *  The (CoreMIDI-supplied) unique ID for the receiver.
 */
@property (nonatomic, readonly) MIDIUniqueID uniqueID;

/**
 *  Whether the receiver is online (available for use) or not.
 */
@property (nonatomic, readonly, getter = isOnline) BOOL online;

/**
 *  The name of the receiver. Devices, entities, and endpoints may all have names.
 */
@property (nonatomic, strong, nullable) NSString *name;

/**
 *  The Apple-recommended  user-visible name of the receiver. May be
 *  identical to the value returned by -name.
 */
@property (nonatomic, strong, readonly, nullable) NSString *displayName;

/**
 *  Indicates whether the object is "virtual". This has slightly different meanings
 *  depending on the type of MIDI object. 
 *
 *  For MIKMIDIDevices, virtual means that the device does not represent a MIDIDeviceRef.
 *  Virtual devices can be used to wrap virtual, deviceless endpoints created
 *  e.g. by other software, some Native Instruments controllers, etc.
 *
 *  For MIKMIDIEntitys, virtual means that the entity is part of a virtual device
 *  and its endpoints are virtual endpoints.
 *
 *  For MIKMIDIEndpoints, virtual means that the endpoint is a virtual endpoint,
 *  rather than an endpoint of a (non-virtual) MIDI device.
 *
 *  @seealso -[MIKMIDIDeviceManager virtualSources]
 *  @seealso -[MIKMIDIDeviceManager virtualDestinations]
 */
@property (nonatomic, readonly) BOOL isVirtual;

@end

NS_ASSUME_NONNULL_END