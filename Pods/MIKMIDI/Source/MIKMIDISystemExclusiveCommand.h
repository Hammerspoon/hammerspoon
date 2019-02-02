//
//  MIKMIDISystemExclusiveCommand.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDISystemMessageCommand.h"
#import "MIKMIDICompilerCompatibility.h"

extern uint32_t const kMIKMIDISysexNonRealtimeManufacturerID;
extern uint32_t const kMIKMIDISysexRealtimeManufacturerID;

extern uint8_t const kMIKMIDISysexChannelDisregard;
extern uint8_t const kMIKMIDISysexBeginDelimiter;
extern uint8_t const kMIKMIDISysexEndDelimiter;

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI System Exclusive (SysEx) message. System exclusive messages are
 *  messages defined by individual manufacturers of MIDI devices. They
 *  can contain arbitrary data and can be used to support commands and responses
 *  not explicitly supported by the standard portion of MIDI spec. There are also
 *  some "Universal Exclusive Mesages", which while a type of SysEx message,
 *  are not manufacturer/device specific.
 */
@interface MIKMIDISystemExclusiveCommand : MIKMIDISystemMessageCommand

/**
 *  Convenience method for creating a SysEx identity request command.
 *  For most MIDI devices, sending this command to them will result in a response including
 *  the device's manufacturer ID along with data to identify the specific family,
 *  model number, and version number of the device.
 *
 *  @return An identity request command object.
 */
+ (instancetype)identityRequestCommand;

/**
 * Initializes the command with raw sysex data and timestamp.
 *
 * @param data Assumed to be valid with begin+end delimiters.
 * @param timeStamp Time at which the first sysex byte was received.
 */
- (id)initWithRawData:(NSData *)data timeStamp:(MIDITimeStamp)timeStamp;

/**
 *  The manufacturer ID for the command. This is used by devices to determine
 *  if the message is one they support. If it is not, the message is ignored.
 *  Manufacturer IDs are assigned by the MIDI Manufacturer's Association, and
 *  a list can be found here: http://www.midi.org/techspecs/manid.php
 *
 *  The default is 0x7E (kMIKMIDISysexNonRealtimeManufacturerID).
 *
 *  The manufacturer ID can be either 1 byte or 3 bytes.
 *
 *  Values 0x7E (kMIKMIDISysexNonRealtimeManufacturerID) and 0x7F (kMIKMIDISysexRealtimeManufacturerID)
 *  mean that the message is a universal (non-manufacturer specific)
 *  system exclusive message.
 */
@property (nonatomic, readonly) UInt32 manufacturerID;

/**
 *  The channel of the message. Only valid for universal exclusive messages,
 *  will always be 0 for non-universal messages.
 */
@property (nonatomic, readonly) UInt8 sysexChannel;

/**
 *  The system exclusive data for the message. 
 *
 *  For universal messages subID's are included in sysexData, for non-universal 
 *  messages, any device specific information (such as modelID, versionID or 
 *  whatever manufactures decide to include) will be included in sysexData.
 */
@property (nonatomic, strong, readonly) NSData *sysexData;

/**
 *  Whether or not the command is a universal exclusive message.
 */
@property (nonatomic, readonly, getter = isUniversal) BOOL universal;

@end

/**
 *  The mutable counter part of MIKMIDISystemExclusiveCommand.
 */
@interface MIKMutableMIDISystemExclusiveCommand : MIKMIDISystemExclusiveCommand

@property (nonatomic, readwrite) UInt32 manufacturerID;
@property (nonatomic, readwrite) UInt8 sysexChannel;
@property (nonatomic, strong, readwrite) NSData *sysexData;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIKMIDICommandType commandType;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, copy, readwrite, null_resettable) NSData *data;

@end

NS_ASSUME_NONNULL_END
