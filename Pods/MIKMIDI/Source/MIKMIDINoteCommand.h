//
//  MIKMIDINoteCommand.h
//  MIKMIDI
//
//  Created by Andrew R Madsen on 9/18/17.
//  Copyright © 2017 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI note on message.
 */
@interface MIKMIDINoteCommand : MIKMIDIChannelVoiceCommand

/**
 *  Convenience method for creating a note on command.
 *
 *  @param note      The note number for the command. Must be between 0 and 127.
 *  @param velocity  The velocity for the command. Must be between 0 and 127.
 *  @param channel   The channel for the command. Must be between 0 and 15.
 *  @param isNoteOn  YES if the command should be a note on command, NO if it should be a note off command.
 *  @param timestamp The timestamp for the command. Pass nil to use the current date/time.
 *
 *  @return An initialized MIKMIDINoteCommand instance.
 */
+ (instancetype)noteCommandWithNote:(NSUInteger)note
						   velocity:(NSUInteger)velocity
							channel:(UInt8)channel
						   isNoteOn:(BOOL)isNoteOn
						  timestamp:(nullable NSDate *)timestamp;



/**
 *  Convenience method for creating a note command.
 *
 *  @param note      The note number for the command. Must be between 0 and 127.
 *  @param velocity  The velocity for the command. Must be between 0 and 127.
 *  @param channel   The channel for the command. Must be between 0 and 15.
 *  @param isNoteOn  YES if the command should be a note on command, NO if it should be a note off command.
 *  @param timestamp The MIDITimestamp for the command.
 *
 *  @return An initialized MIKMIDINoteCommand instance.
 */
+ (instancetype)noteCommandWithNote:(NSUInteger)note
						   velocity:(NSUInteger)velocity
							channel:(UInt8)channel
						   isNoteOn:(BOOL)isNoteOn
					  midiTimeStamp:(MIDITimeStamp)timestamp;



/**
 *  The note number for the message. In the range 0-127.
 */
@property (nonatomic, readonly) NSUInteger note;

/**
 *  Velocity of the note on message. In the range 0-127.
 */
@property (nonatomic, readonly) NSUInteger velocity;

/**
 *  YES if the receiver is a note on, NO if it is a note off.
 */
@property (nonatomic, readonly, getter=isNoteOn) BOOL noteOn;

@end

/**
 *  The mutable counterpart of MIKMIDINoteCommand.
 */
@interface MIKMutableMIDINoteCommand : MIKMIDINoteCommand

@property (nonatomic, readwrite) NSUInteger note;
@property (nonatomic, readwrite) NSUInteger velocity;
@property (nonatomic, readwrite, getter=isNoteOn) BOOL noteOn;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@end

NS_ASSUME_NONNULL_END
