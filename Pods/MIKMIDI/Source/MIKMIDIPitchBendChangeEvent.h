//
//  MIKMIDIPitchBendChangeEvent.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/4/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A pitch bed change event.
 *
 *  This event indicates a pitch bend change. On devices, pitch
 *  bends are usually generated using a wheel or lever.
 */
@interface MIKMIDIPitchBendChangeEvent : MIKMIDIChannelEvent

/**
 *  A 14-bit value indicating the pitch bend.
 *  Center is 0x2000 (8192). 
 *  Valid range is from 0-16383.
 */
@property (nonatomic, readonly) UInt16 pitchChange;

@end

/**
 *  The mutable counterpart of MIKMIDIPitchBendChangeEvent.
 */
@interface MIKMutableMIDIPitchBendChangeEvent : MIKMIDIPitchBendChangeEvent

@property (nonatomic, readonly) UInt16 pitchChange;

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, strong, readwrite, null_resettable) NSMutableData *data;
@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

NS_ASSUME_NONNULL_END