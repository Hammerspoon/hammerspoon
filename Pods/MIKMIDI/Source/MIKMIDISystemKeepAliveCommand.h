//
//  MIKMIDISystemKeepAliveCommand.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/9/17.
//  Copyright © 2017 Mixed In Key. All rights reserved.
//

#import "MIKMIDISystemMessageCommand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI System Keep Alive message (aka Active Sensing).
 *  Keep alive messages are sent repeatedly
 *  to tell the receiver of them that the MIDI connection is alive and working.
 *  Not all devices will send these at all.
 *
 *  Per the MIDI spec, if a device *does* receive a keep alive message, it should
 *  expect to receive another no more than 300 ms later. If it does not, it can
 *  assume the connection has been terminated, and turn off all currently active
 *  voices/notes.
 *
 *  Note that MIKMIDI doesn't (currently) implement this behavior at all, and it
 *  is up to MIKMIDI clients to implement it if so desired.
 */
@interface MIKMIDISystemKeepAliveCommand : MIKMIDISystemMessageCommand


/**
 *  Convenience method for creating a keep alive command, also known
 *  as an active sensing command.
 *
 *
 *  @return A keep alive command object.
 */
+ (instancetype)keepAliveCommand;

@end

/**
 *  The mutable counter part of MIKMIDISystemKeepAliveCommand.
 */
@interface MIKMutableMIDISystemKeepAliveCommand : MIKMIDISystemKeepAliveCommand

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIKMIDICommandType commandType;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, copy, readwrite, null_resettable) NSData *data;

@end

NS_ASSUME_NONNULL_END
