//
//  MIKMIDIDestinationEndpoint.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/8/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEndpoint.h"
#import "MIKMIDICommandScheduler.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIDestinationEndpoint represents a source (input) MIDI endpoint.
 *  It is essentially an Objective-C wrapper for instances of CoreMIDI's MIDIEndpoint class
 *  which are kMIDIObjectType_Destination type endpoints.
 *
 *  MIDI destination endpoints are contained by MIDI entities, which are in turn contained by MIDI devices.
 *  MIDI messages can be outputed through a destination endpoint using MIKMIDIDeviceManager's
 *  -sendCommands:toEndpoint:error: method.
 *
 *  Note that MIKMIDIDestinationEndpoint does not declare any methods of its own. All its methods can be
 *  found on its superclasses: MIKMIDIEndpoint and MIKMIDIObject. Also, MIKMIDIDestinationEndpoint itself
 *  is only used to represent MIDI endpoints owned by external applications/devices. To create virtual
 *  destination endpoints to be owned by your application and offered to others, use its subclass,
 *  MIKMIDIClientDestinationEndpoint instead.
 *
 *  @see -[MIKMIDIDeviceManager sendCommands:toEndpoint:error:]
 *  @see MIKMIDIClientDestinationEndpoint
 */
@interface MIKMIDIDestinationEndpoint : MIKMIDIEndpoint <MIKMIDICommandScheduler>

/**
 *  Unschedules previously-sent events. Events that have been scheduled with timestamps
 *  in the future are cancelled and won't be sent. 
 */
- (void)unscheduleAllPendingEvents;

@end

NS_ASSUME_NONNULL_END