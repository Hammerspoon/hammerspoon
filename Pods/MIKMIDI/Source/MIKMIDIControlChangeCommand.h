//
//  MIKMIDIControlChangeCommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI control change message.
 */
@interface MIKMIDIControlChangeCommand : MIKMIDIChannelVoiceCommand

/**
 *  Convience method for creating a single, 14-bit control change command from its component
 *  messages. The two commands passed into this method must comply with the MIDI specification
 *  for 14-bit control change messages.
 *
 *  The MIDI spec allows for 14-bit control change commands. These are actually sent as two
 *  sequential commands where the second command has a controller number equal to the first
 *  message's controllerNumber plus 32, and whose value is the least significant 7-bits of 
 *  the 14-bit value.
 *
 *  @note This method is used internally by MIKMIDI, to coalesce incoming 14-bit control change commands.
 *  it is not generally useful to external users of MIKMIDI. If you're simply trying to create a new
 *  MIKMIDIControlChangeCommand instance, you should use plain alloc/init instead.
 *
 *  @param msbCommand The command containing the most significant 7 bits of value data (ie. the first command).
 *  @param lsbCommand The command containing the least significant 7 bits of value data (ie. the second command).
 *
 *  @return A new, single MIKMIDIControlChangeCommand instance containing 14-bit value data, and whose 
 *  fourteenBitCommand property is set to YES.
 */
+ (nullable instancetype)commandByCoalescingMSBCommand:(MIKMIDIControlChangeCommand *)msbCommand andLSBCommand:(MIKMIDIControlChangeCommand *)lsbCommand;

/**
 *  The MIDI control number for the command.
 */
@property (nonatomic, readonly) NSUInteger controllerNumber;

/**
 *  The controlValue of the command. 
 *
 *  This method returns the same value as -value. Note that this is always a 7-bit (0-127)
 *  value, even for a fourteen bit command. To retrieve the 14-bit value, use -fourteenBitValue.
 *
 *  @see -fourteenBitCommand
 */
@property (nonatomic, readonly) NSUInteger controllerValue;

/**
 *  The 14-bit value of the command.
 *
 *  This property always returns a 14-bit value (ranging from 0-16383). If the receiver is
 *  not a 14-bit command (-isFourteenBitCommand returns NO), the 7 least significant
 *  bits will always be 0.
 */
@property (nonatomic, readonly) NSUInteger fourteenBitValue;

/**
 *  YES if the command contains 14-bit value data.
 *
 *  If this property returns YES, -fourteenBitValue will return a precision value in the range 0-16383
 *
 *  @see +commandByCoalescingMSBCommand:andLSBCommand:
 */
@property (nonatomic, readonly, getter = isFourteenBitCommand) BOOL fourteenBitCommand;

@end

/**
 *  The mutable counterpart of MIKMIDIControlChangeCommand.
 */
@interface MIKMutableMIDIControlChangeCommand : MIKMIDIControlChangeCommand

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@property (nonatomic, readwrite) NSUInteger controllerNumber;
@property (nonatomic, readwrite) NSUInteger controllerValue;

/**
 *  The 14-bit value of the command.
 *
 *  This property always returns a 14-bit value (ranging from 0-16383). If the receiver is
 *  not a 14-bit command (-isFourteenBitCommand returns NO), the 7 least significant
 *  bits will always be 0, and will be discarded when setting this property.
 *
 *  When setting this property, if the fourteenBitCommand property has not been set to YES,
 *  the 7 LSbs will be discarded/ignored.
 */
@property (nonatomic, readwrite) NSUInteger fourteenBitValue;

@property (nonatomic, readwrite, getter = isFourteenBitCommand) BOOL fourteenBitCommand;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIKMIDICommandType commandType;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, copy, readwrite, null_resettable) NSData *data;

@end

NS_ASSUME_NONNULL_END