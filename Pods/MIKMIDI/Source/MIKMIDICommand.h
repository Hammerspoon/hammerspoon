//
//  MIKMIDICommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import "MIKMIDICompilerCompatibility.h"

/**
 *  Types of MIDI messages. These values correspond directly to the MIDI command type values
 *  found in MIDI message data.
 *
 *  @note Not all of these MIDI message types are currently explicitly supported by MIKMIDI.
 */
typedef NS_ENUM(NSUInteger, MIKMIDICommandType) {
	/**  Note off command. */
	MIKMIDICommandTypeNoteOff = 0x8f,
	/**  Note on command. */
	MIKMIDICommandTypeNoteOn = 0x9f,
	/**  Polyphonic key pressure command. */
	MIKMIDICommandTypePolyphonicKeyPressure = 0xaf,
	/**  Control change command. This is the most common command sent by MIDI controllers. */
	MIKMIDICommandTypeControlChange = 0xbf,
	/**  Program change command. */
	MIKMIDICommandTypeProgramChange = 0xcf,
	/**  Channel pressure command. */
	MIKMIDICommandTypeChannelPressure = 0xdf,
	/**  Pitch wheel change command. */
	MIKMIDICommandTypePitchWheelChange = 0xef,
	/**  System message command. */
	MIKMIDICommandTypeSystemMessage = 0xff,
	/**  System message command. */
	MIKMIDICommandTypeSystemExclusive = 0xf0,
	/**  System exclusive (SysEx) command. */
	MIKMIDICommandTypeSystemTimecodeQuarterFrame = 0xf1,
	/**  System song position pointer command. */
	MIKMIDICommandTypeSystemSongPositionPointer = 0xf2,
	/**  System song select command. */
	MIKMIDICommandTypeSystemSongSelect = 0xf3,
	/**  System tune request command. */
	MIKMIDICommandTypeSystemTuneRequest = 0xf6,
	/**  System timing clock command. */
	MIKMIDICommandTypeSystemTimingClock = 0xf8,
	/**  System timing clock command. */
	MIKMIDICommandTypeSystemStartSequence = 0xfa,
	/**  System start sequence command. */
	MIKMIDICommandTypeSystemContinueSequence = 0xfb,
	/**  System continue sequence command. */
	MIKMIDICommandTypeSystemStopSequence = 0xfc,
	/**  System keep alive message. */
	MIKMIDICommandTypeSystemKeepAlive = 0xfe,
};

@class MIKMIDIMappingItem;

NS_ASSUME_NONNULL_BEGIN

/**
 *  In MIKMIDI, MIDI messages are objects. Specifically, they are instances of MIKMIDICommand or one of its
 *  subclasses. MIKMIDICommand's subclasses each represent a specific type of MIDI message, for example,
 *  control change command messages will be instances of MIKMIDIControlChangeCommand.
 *  MIKMIDICommand includes properties for getting information and data common to all MIDI messages.
 *  Its subclasses implement additional method and properties specific to messages of their associated type.
 *
 *  MIKMIDICommand is also available in mutable variants, most useful for creating commands to be sent out
 *  by your application.
 *
 *  To create a new command, typically, you should use +commandForCommandType:.
 *
 *  Subclass MIKMIDICommand
 *  -----------------------
 *
 *  Support for the various MIDI message types is provided by type-specific subclasses of MIKMIDICommand.
 *  For example, Control Change messages are represented using MIKMIDIControlChangeCommand. MIKMIDI
 *  includes a limited number of MIKMIDICommand subclasses to support the most common MIDI message types.
 *  To support a new command type, you should create a new subclass of MIKMIDICommand (and please consider
 *  contributing it to the main MIKMIDI repository!). If you implement this subclass according to the rules
 *  explained below, it will automatically be used to represent incoming MIDI commands matching its MIDI command type.
 *
 *  To successfully subclass MIKMIDICommand, you *must* override at least the following methods:
 *  
 *  - `+supportedMIDICommandTypes:` - Return an array of one or more MIKMIDICommandTypes that your subclass supports.
 *  - `+immutableCounterPartClass` - Return the subclass itself (eg. `return [MIKMIDINewTypeCommand class];`)
 *  - `+mutableCounterPartClass` - Return the mutable counterpart class (eg. `return [MIKMIDIMutableNewTypeCommand class;]`)
 *
 *  Optionally, override `-additionalCommandDescription` to provide an additional, type-specific description string.
 *
 *  You must also implement `+load` and call `[MIKMIDICommand registerSubclass:self]` to register your subclass with
 *  the MIKMIDICommand machinery.
 *
 *  When creating a subclass of MIKMIDICommand, you should also create a mutable variant which is itself
 *  a subclass of your type-specific MIKMIDICommand subclass. The mutable subclass should override `+isMutable`
 *  and return YES.
 *  
 *  If your subclass adds additional properties, beyond those supported by MIKMIDICommand itself, those properties
 *  should only be settable on instances of the mutable variant class. The preferred way to accomplish this is to 
 *  implement the setters on the *immutable*, base subclass. In their implementations, check to see if self is
 *  mutable, and if not, raise an exception. Use the following line of code:
 *
 *		if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
 *
 *  For a straightforward example of a MIKMIDICommand subclass, see MIKMIDINoteOnCommand.
 *
 */
@interface MIKMIDICommand : NSObject <NSCopying>

/**
 *  Convenience method for creating a new MIKMIDICommand instance from a MIDIPacket as received or created
 *  using CoreMIDI functions. For command types for which there is a specific MIKMIDICommand subclass,
 *  an instance of the appropriate subclass will be returned.
 *
 *  @note This method is used by MIKMIDI's internal machinery, and its use by MIKMIDI
 *  clients, while not disallowed, is not typical. Normally, +commandForCommandType: should be used.
 *
 *  @param packet A pointer to an MIDIPacket struct.
 *
 *  @return For supported command types, an initialized MIKMIDICommand subclass. Otherwise, an instance
 *  of MIKMIDICommand itself. nil if there is an error.
 *
 *  @see +commandForCommandType:
 */
+ (instancetype)commandWithMIDIPacket:(MIDIPacket *)packet;

/**
 *  Convenience method for creating a new MIKMIDICommand instance from a MIDIPacket as received or created
 *  using CoreMIDI functions. For command types for which there is a specific MIKMIDICommand subclass,
 *  an instance of the appropriate subclass will be returned.
 *
 *  @note This method is used by MIKMIDI's internal machinery, and its use by MIKMIDI
 *  clients, while not disallowed, is not typical. Normally, +commandForCommandType: should be used.
 *
 *  @param packet A pointer to an MIDIPacket struct.
 *
 *  @return An NSArray containing initialized MIKMIDICommand subclass instances for each MIDI
 *  message of a supported command type. For unsupported command types, an instance of 
 *  MIKMIDICommand itself will be used. Returns nil if there is an error.
 *
 *  @see +commandForCommandType:
 */
+ (MIKArrayOf(MIKMIDICommand *) *)commandsWithMIDIPacket:(MIDIPacket *)packet;


/**
 *  Convenience method for creating a new MIKMIDICommand. For command types for which there is a
 *  specific MIKMIDICommand subclass, an instance of the appropriate subclass will be returned.
 *
 *  @param commandType The type of MIDI command to create. See MIKMIDICommandType for a list
 *  of possible values.
 *
 *  @return For supported command types, an initialized MIKMIDICommand subclass. Otherwise, an instance
 *  of MIKMIDICommand itself. nil if there is an error.
 */
+ (instancetype)commandForCommandType:(MIKMIDICommandType)commandType; // Most useful for mutable commands

/**
 *  The time at which the MIDI message was received. Will be set for commands received from a connected MIDI source. For commands
 *  to be sent (ie. created by the MIKMIDI-using application), this must be set manually.
 */
@property (nonatomic, strong, readonly) NSDate *timestamp;

/**
 *  The receiver's command type. See MIKMIDICommandType for a list of possible values.
 */
@property (nonatomic, readonly) MIKMIDICommandType commandType;

/**
 *  The MIDI status byte. The exact meaning of the contents
 *  of this byte differ for different command types. See
 *  http://www.midi.org/techspecs/midimessages.php for a information
 *  about the contents of this value.
 */
@property (nonatomic, readonly) UInt8 statusByte;

/**
 *  The first byte of the MIDI data (after the command type).
 */
@property (nonatomic, readonly) UInt8 dataByte1;

/**
 *  The second byte of the MIDI data (after the command type).
 */
@property (nonatomic, readonly) UInt8 dataByte2;

/**
 *  The timestamp for the receiver, expressed as a host clock time. This is the timestamp
 *  used by CoreMIDI. Usually the timestamp property, which returns an NSDate, will be more useful.
 *
 *  @see -timestamp
 */
@property (nonatomic, readonly) MIDITimeStamp midiTimestamp;

/**
 *  The raw data that makes up the receiver.
 */
@property (nonatomic, copy, readonly, null_resettable) NSData *data;

/**
 *  Optional mapping item used to route the command. This must be set by client code that handles
 *  receiving MIDI commands. Allows responders to understand how a command was mapped, especially
 *  useful to determine interaction type so that responders can interpret the command correctly.
 */
@property (nonatomic, strong, nullable) MIKMIDIMappingItem *mappingItem;

@end

/**
 *  Mutable subclass of MIKMIDICommand. All MIKMIDICommand subclasses have mutable variants.
 */
@interface MIKMutableMIDICommand : MIKMIDICommand

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIKMIDICommandType commandType;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, copy, readwrite) NSData *data;

@end

/**
 *  Allocates and returns (by reference) a CoreMIDI MIDIPacketList created from an array of MIKMIDICommand instances.
 *  The created MIDIPacketList will be sized according to the number of commands and their contents. Ownership is
 *  transfered to the caller which becomes responsible for freeing the allocated memory.
 *  Used by MIKMIDI when sending commands. Typically, this is not needed by clients of MIKMIDI.
 *
 *  @param outPacketList   A pointer to a pointer to a MIDIPacketList structure which will point to the created MIDIPacketList
 *                         upon success.
 *  @param commands        An array of MIKMIDICommand instances.
 *
 *  @return YES if creating the packet list was successful, NO if an error occurred.
 */
BOOL MIKCreateMIDIPacketListFromCommands(MIDIPacketList * _Nonnull * _Nonnull outPacketList, MIKArrayOf(MIKMIDICommand *) *commands);

NS_ASSUME_NONNULL_END