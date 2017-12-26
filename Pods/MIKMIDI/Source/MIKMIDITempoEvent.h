//
//  MIKMIDITempoEvent.h
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/** 
 *  A MIDI tempo event.
 */
@interface MIKMIDITempoEvent : MIKMIDIEvent

/**
 *  Creates and initializes a new MIKMIDITempoEvent.
 *
 *  @param timeStamp The time stamp for the tempo event.
 *
 *  @param bpm The beats per minute of the tempo event.
 *
 *  @return A new instance of MIKMIDITempoEvent
 */
+ (instancetype)tempoEventWithTimeStamp:(MusicTimeStamp)timeStamp tempo:(Float64)bpm;

/**
 *  The beats per minute of the tempo event.
 */
@property (nonatomic, readonly) Float64 bpm;

@end

/**
 *  The mutable counterpart of MIKMIDITempoEvent.
 */
@interface MIKMutableMIDITempoEvent : MIKMIDITempoEvent

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, strong, readwrite, null_resettable) NSMutableData *data;
@property (nonatomic, readwrite) Float64 bpm;

@end

NS_ASSUME_NONNULL_END