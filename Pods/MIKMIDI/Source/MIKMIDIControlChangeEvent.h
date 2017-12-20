//
//  MIKMIDIControlChangeEvent.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/3/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Control change events are typically sent when a controller value changes. 
 *  Controllers include devices such as pedals and levers.
 *
 *  This event is the counterpart to MIKMIDIControlChangeCommand in the context
 *  of sequences/MIDI Files.
 */
@interface MIKMIDIControlChangeEvent : MIKMIDIChannelEvent

/**
 *  The MIDI controller number for the event.
 *  Only values from 0-127 are valid.
 */
@property (nonatomic, readonly) NSUInteger controllerNumber;

/**
 *  The value of the controller specified by controllerNumber.
 *  Only values from 0-127 are valid.
 */
@property (nonatomic, readonly) NSUInteger controllerValue;

@end

/**
 *  The mutable counter part of MIKMIDIControlChangeEvent
 */
@interface MIKMutableMIDIControlChangeEvent : MIKMIDIControlChangeEvent

@property (nonatomic, readwrite) NSUInteger controllerNumber;
@property (nonatomic, readwrite) NSUInteger controllerValue;

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, strong, readwrite, null_resettable) NSMutableData *data;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

NS_ASSUME_NONNULL_END