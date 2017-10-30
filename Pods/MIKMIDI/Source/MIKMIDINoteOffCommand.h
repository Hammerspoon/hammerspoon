//
//  MIKMIDINoteOffCommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI note off message.
 */
@interface MIKMIDINoteOffCommand : MIKMIDIChannelVoiceCommand

/**
 *  Convenience method for creating a note off command.
 *
 *  @param note      The note number for the command. Must be between 0 and 127.
 *  @param velocity  The velocity for the command. Must be between 0 and 127.
 *  @param channel   The channel for the command. Must be between 0 and 15.
 *  @param timestamp The timestamp for the command. Pass nil to use the current date/time.
 *
 *  @return An initialized MIKMIDINoteOffCommand instance.
 */
+ (instancetype)noteOffCommandWithNote:(NSUInteger)note
							  velocity:(NSUInteger)velocity
							   channel:(UInt8)channel
							 timestamp:(nullable NSDate *)timestamp;

/**
 *  Convenience method for creating a note off command.
 *
 *  @param note      The note number for the command. Must be between 0 and 127.
 *  @param velocity  The velocity for the command. Must be between 0 and 127.
 *  @param channel   The channel for the command. Must be between 0 and 15.
 *  @param timestamp The MIDITimeStamp for the command.
 *
 *  @return An initialized MIKMIDINoteOffCommand instance.
 */
+ (instancetype)noteOffCommandWithNote:(NSUInteger)note
							  velocity:(NSUInteger)velocity
							   channel:(UInt8)channel
						 midiTimeStamp:(MIDITimeStamp)timestamp;

/**
 *  The note number for the message. In the range 0-127.
 */
@property (nonatomic, readonly) NSUInteger note;

/**
 *  Velocity of the note off message. In the range 0-127.
 */
@property (nonatomic, readonly) NSUInteger velocity;

@end

/**
 *  The mutable counterpart of MIKMIDINoteOffCommand.
 */
@interface MIKMutableMIDINoteOffCommand : MIKMIDINoteOffCommand

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@property (nonatomic, readwrite) NSUInteger note;
@property (nonatomic, readwrite) NSUInteger velocity;

@end

NS_ASSUME_NONNULL_END