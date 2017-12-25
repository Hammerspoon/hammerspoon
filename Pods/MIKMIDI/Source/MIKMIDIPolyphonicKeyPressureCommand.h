//
//  MIKMIDIPolyphonicKeyPressureCommand.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/12/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"

/**
 *  A MIDI polyphonic key pressure message. This message is most often sent by pressing 
 *  down on the key after it "bottoms out".
 */
@interface MIKMIDIPolyphonicKeyPressureCommand : MIKMIDIChannelVoiceCommand

/// The note number for the message. In the range 0-127.
@property (nonatomic, readonly) NSUInteger note;

/// Key pressure of the polyphonic key pressure message. In the range 0-127.
@property (nonatomic, readonly) NSUInteger pressure;

@end

/**
 *  The mutable counterpart to MIKMIDIPolyphonicKeyPressureCommand.
 */
@interface MIKMutableMIDIPolyphonicKeyPressureCommand : MIKMIDIPolyphonicKeyPressureCommand

/// The note number for the message. In the range 0-127.
@property (nonatomic, readwrite) NSUInteger note;

/// Key pressure of the polyphonic key pressure message. In the range 0-127.
@property (nonatomic, readwrite) NSUInteger pressure;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@end
