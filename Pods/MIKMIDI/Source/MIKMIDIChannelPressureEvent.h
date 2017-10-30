//
//  MIKMIDIChannelPressureEvent.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/4/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A channel pressure (aftertouch) event.
 *
 *  This event is different from MIKMIDIPolyphonicKeyPressureEvent.
 *  This event is used to indicate the single greatest pressure value
 *  (of all the current depressed keys).
 */
@interface MIKMIDIChannelPressureEvent : MIKMIDIChannelEvent

/**
 *  The pressure of the event. From 0-127.
 */
@property (nonatomic, readonly) UInt8 pressure;

@end

/**
 *  The mutable counter part of MIKMIDIChannelPressureEvent
 */
@interface MIKMutableMIDIChannelPressureEvent : MIKMIDIChannelPressureEvent

@property (nonatomic, readwrite) UInt8 pressure;

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, strong, readwrite, null_resettable) NSMutableData *data;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

NS_ASSUME_NONNULL_END