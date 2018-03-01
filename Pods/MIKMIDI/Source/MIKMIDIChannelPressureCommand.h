//
//  MIKMIDIChannelPressureCommand.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/12/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDIChannelPressureCommand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI channel pressure message. This message is most often sent by pressing
 *  down on the key after it "bottoms out". This differs from a MIKMIDIPolyphonicKeyPressureCommand
 *  in that is the single greatest pressure of all currently depressed keys, hence the lack
 *  of a note property.
 */
@interface MIKMIDIChannelPressureCommand : MIKMIDIChannelVoiceCommand

/**
 Convenience method for creating a channel pressure command.

 @param pressure The pressure for the command. Must be between 0 and 127
 @param channel The channel for the command. Must be between 0 and 15.
 @param timestamp The timestamp for the command. Pass nil to use the current date/time.
 @return An initialized MIKMIDIChannelPressureCommand instance.
 */
+ (instancetype)channelPressureCommandWithPressure:(NSUInteger)pressure channel:(UInt8)channel timestamp:(nullable NSDate *)timestamp;

/// Key pressure of the channel pressure message. In the range 0-127.
@property (nonatomic, readonly) NSUInteger pressure;

@end

@interface MIKMutableMIDIChannelPressureCommand : MIKMIDIChannelPressureCommand

/// Key pressure of the channel pressure message. In the range 0-127.
@property (nonatomic, readwrite) NSUInteger pressure;

@property (nonatomic, strong, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) MIDITimeStamp midiTimestamp;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@end

NS_ASSUME_NONNULL_END
