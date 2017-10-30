//
//  MIKMIDIChannelVoiceCommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDICommand.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIChannelVoiceCommand is used to represent MIDI messages whose type is
 *  any of the channel voice command subtypes. Specific support for channel voice command
 *  subtypes is provided by subclasses of MIKMIDIChannelVoiceCommand (e.g.
 *  MIKMIDIControlChangeCommand, MIKMIDINoteOnCommand, etc.)
 */
@interface MIKMIDIChannelVoiceCommand : MIKMIDICommand

/**
 *  The MIDI channel the message was or should be sent on. Valid
 *  values are from 0-15.
 */
@property (nonatomic, readonly) UInt8 channel;

/**
 *  The value of the command. The meaning of this property is
 *  different for different subtypes. For example, for a control change command,
 *  this is the controllerValue. For a note on command, this is the
 *  velocity.
 */
@property (nonatomic, readonly) NSUInteger value;

@end

/**
 *  The mutable counterpart of MIKMIDIChannelVoiceCommand.
 */
@interface MIKMutableMIDIChannelVoiceCommand : MIKMIDIChannelVoiceCommand

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIKMIDICommandType commandType;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, copy, readwrite, null_resettable) NSData *data;

@end

NS_ASSUME_NONNULL_END