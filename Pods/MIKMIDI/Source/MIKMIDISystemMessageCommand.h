//
//  MIKMIDISystemMessageCommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDICommand.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI system message command. This class is also the base class for
 *  subclasses representing specific system message subtypes (e.g. SysEx).
 */
@interface MIKMIDISystemMessageCommand : MIKMIDICommand

@end

/**
 *  Mutable counterpart for MIKMIDISystemMessageCommand.
 */
@interface MIKMutableMIDISystemMessageCommand : MIKMIDISystemMessageCommand

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIKMIDICommandType commandType;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, copy, readwrite, null_resettable) NSData *data;

@end

NS_ASSUME_NONNULL_END