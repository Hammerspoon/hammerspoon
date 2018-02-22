//
//  MIKMIDINoteOffCommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteCommand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI note off message.
 */
@interface MIKMIDINoteOffCommand : MIKMIDINoteCommand

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
*  Convenience method to create a note off command from a note on command with zero velocity,
*  or another note off command.
*
*  Some MIDI devices send a note on message with zero velocity when a key or button is released,
*  instead of sending a note off command. Writing code to deal with this possibility can be
*  somewhat ugly, especially in Swift. Using this method, a note on command can be "transformed"
*  into a note off command if its velocity is zero with a single call, then a single execution path
*  to handle note off commands can be written.
*
*  Note that this method returns nil if the passed in command has a velocity greater than zero.
*  @param note An instance of MIKNoteCommand.
*  @return An instance of MIKMIDINoteOffCommand with the same note, channel, and timestamp as note.
*  nil if note is a note on whose velocity is greater than zero.
*/
+ (instancetype _Nullable)noteOffCommandWithNoteCommand:(MIKMIDINoteCommand *)note;

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

#pragma mark - Unavailable

@interface MIKMIDINoteOffCommand ()

+ (instancetype)noteCommandWithNote:(NSUInteger)note
						   velocity:(NSUInteger)velocity
							channel:(UInt8)channel
						   isNoteOn:(BOOL)isNoteOn
						  timestamp:(nullable NSDate *)timestamp NS_UNAVAILABLE;

+ (instancetype)noteCommandWithNote:(NSUInteger)note
						   velocity:(NSUInteger)velocity
							channel:(UInt8)channel
						   isNoteOn:(BOOL)isNoteOn
					  midiTimeStamp:(MIDITimeStamp)timestamp NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
