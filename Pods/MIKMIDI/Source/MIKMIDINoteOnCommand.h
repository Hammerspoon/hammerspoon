//
//  MIKMIDINoteOnCommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteCommand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI note on message.
 */
@interface MIKMIDINoteOnCommand : MIKMIDINoteCommand

/**
 *  Convenience method for creating a note on command.
 *
 *  @param note      The note number for the command. Must be between 0 and 127.
 *  @param velocity  The velocity for the command. Must be between 0 and 127.
 *  @param channel   The channel for the command. Must be between 0 and 15.
 *  @param timestamp The timestamp for the command. Pass nil to use the current date/time.
 *
 *  @return An initialized MIKMIDINoteOnCommand instance.
 */
+ (instancetype)noteOnCommandWithNote:(NSUInteger)note
							 velocity:(NSUInteger)velocity
							  channel:(UInt8)channel
							timestamp:(nullable NSDate *)timestamp;


/**
 *  Convenience method for creating a note on command.
 *
 *  @param note      The note number for the command. Must be between 0 and 127.
 *  @param velocity  The velocity for the command. Must be between 0 and 127.
 *  @param channel   The channel for the command. Must be between 0 and 15.
 *  @param timestamp The MIDITimestamp for the command.
 *
 *  @return An initialized MIKMIDINoteOnCommand instance.
 */
+ (instancetype)noteOnCommandWithNote:(NSUInteger)note
							 velocity:(NSUInteger)velocity
							  channel:(UInt8)channel
						midiTimeStamp:(MIDITimeStamp)timestamp;

@end

/**
 *  The mutable counterpart of MIKMIDINoteOnCommand.
 */
@interface MIKMutableMIDINoteOnCommand : MIKMIDINoteOnCommand

@property (nonatomic, readwrite) NSUInteger note;
@property (nonatomic, readwrite) NSUInteger velocity;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@end

#pragma mark - Unavailable

@interface MIKMIDINoteOnCommand ()

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
