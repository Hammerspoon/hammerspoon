//
//  MIKMIDIPitchBendChangeCommand.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/5/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI pitch bend change command.
 *
 *  On devices, pitch bends messages are usually generated using a wheel or lever.
 */
@interface MIKMIDIPitchBendChangeCommand : MIKMIDIChannelVoiceCommand

/**
 *  A 14-bit value indicating the pitch bend.
 *  Center is 0x2000 (8192).
 *  Valid range is from 0-16383.
 */
@property (nonatomic, readonly) UInt16 pitchChange;

@end

@interface MIKMutableMIDIPitchBendChangeCommand : MIKMIDIPitchBendChangeCommand

@property (nonatomic, readwrite) UInt16 pitchChange;

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