//
//  MIKMIDIPolyphonicKeyPressureEvent.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/4/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A polyphonic key pressure (aftertouch) event.
 *
 *  This event most often represents pressing down on a key after it "bottoms out".
 */
@interface MIKMIDIPolyphonicKeyPressureEvent : MIKMIDIChannelEvent

/**
 *  The MIDI note number for the event.
 */
@property (nonatomic, readonly) UInt8 note;

/**
 *  The pressure of the event. From 0-127.
 */
@property (nonatomic, readonly) UInt8 pressure;

@end

/**
 *  The mutable counter part of MIKMIDIPolyphonicKeyPressureEvent
 */
@interface MIKMutableMIDIPolyphonicKeyPressureEvent : MIKMIDIPolyphonicKeyPressureEvent

@property (nonatomic, readwrite) UInt8 note;
@property (nonatomic, readwrite) UInt8 pressure;

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, strong, readwrite, null_resettable) NSMutableData *data;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

NS_ASSUME_NONNULL_END