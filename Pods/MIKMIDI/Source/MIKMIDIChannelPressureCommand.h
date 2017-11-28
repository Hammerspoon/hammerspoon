//
//  MIKMIDIChannelPressureCommand.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/12/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDIChannelPressureCommand.h"

/**
 *  A MIDI channel pressure message. This message is most often sent by pressing
 *  down on the key after it "bottoms out". This differs from a MIKMIDIPolyphonicKeyPressureCommand
 *  in that is the single greatest pressure of all currently depressed keys, hence the lack
 *  of a note property.
 */
@interface MIKMIDIChannelPressureCommand : MIKMIDIChannelVoiceCommand

/// Key pressure of the channel pressure message. In the range 0-127.
@property (nonatomic, readonly) NSUInteger pressure;

@end

@interface MIKMutableMIDIChannelPressureCommand : MIKMIDIChannelPressureCommand

/// Key pressure of the channel pressure message. In the range 0-127.
@property (nonatomic, readwrite) NSUInteger pressure;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@end