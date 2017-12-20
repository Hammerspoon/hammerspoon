//
//  MIKMIDIChannelEvent.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/3/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDIChannelEvent : MIKMIDIEvent

/**
 *  Convenience method for creating a new MIKMIDIChannelEvent from a CoreMIDI MIDIChannelMessage struct.
 *
 *  @param timeStamp A MusicTimeStamp value indicating the timestamp for the event.
 *  @param message A MIDIChannelMessage struct containing properties for the event.
 *
 *  @return A new instance of a subclass of MIKMIDIChannelEvent, or nil if there is an error.
 */
+ (nullable instancetype)channelEventWithTimeStamp:(MusicTimeStamp)timeStamp message:(MIDIChannelMessage)message;

// Properties

/**
 *  The channel for the MIDI event.
 */
@property (nonatomic, readonly) UInt8 channel;

/**
 *  The first byte of data for the event.
 */
@property (nonatomic, readonly) UInt8 dataByte1;

/**
 *  The second byte of data for the event.
 */
@property (nonatomic, readonly) UInt8 dataByte2;

@end

/**
 *  The mutable counterpart of MIKMIDIChannelEvent.
 */
@interface MIKMutableMIDIChannelEvent : MIKMIDIChannelEvent

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, strong, readwrite, null_resettable) NSMutableData *data;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

NS_ASSUME_NONNULL_END

#pragma mark -

#import "MIKMIDICommand.h"

@class MIKMIDIClock;

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDICommand (MIKMIDIChannelEventToCommands)

+ (nullable instancetype)commandFromChannelEvent:(MIKMIDIChannelEvent *)event clock:(MIKMIDIClock *)clock;

@end

NS_ASSUME_NONNULL_END