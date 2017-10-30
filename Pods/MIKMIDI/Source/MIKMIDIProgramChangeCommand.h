//
//  MIKMIDIProgramChangeCommand.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 1/14/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI program change message.
 *
 *  Program change messages indicate a change in the patch number.
 *  These messages can be sent to to a MIDI device or synthesizer to
 *	change the instrument the instrument/voice being used to synthesize MIDI.
 */
@interface MIKMIDIProgramChangeCommand : MIKMIDIChannelVoiceCommand

/**
 *  The program (aka patch) number. From 0-127.
 */
@property (nonatomic, readonly) NSUInteger programNumber;

@end

/**
 *  The mutable counterpart of MIKMIDIProgramChangeCommand
 */
@interface MIKMutableMIDIProgramChangeCommand : MIKMIDIProgramChangeCommand

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@property (nonatomic, readwrite) NSUInteger programNumber;

@end

NS_ASSUME_NONNULL_END