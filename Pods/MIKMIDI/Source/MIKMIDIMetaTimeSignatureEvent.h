//
//  MIKMIDITimeSignatureEvent.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaEvent.h"
#import "MIKMIDICompilerCompatibility.h"

/**
 *  Represents a time signature. Note that in contrast to time signature events in raw MIDI,
 *  the denominator here is the "natural" denominator for the time signature. e.g. 4/4 time
 *  is represented with a numerator of 4 and denominator of 4.
 */
typedef struct {
	UInt8 numerator; /// The number of beats per measure.
	UInt8 denominator; // The fraction of a whole note per beat (e.g. 4 here means a quarter note per beat)
} MIKMIDITimeSignature;

/**
 *  Convenience function to create a MIDITimeSignature struct.
 *
 *  For example, to create a time signature struct for 4/4 time:
 *  MIKMIDITimeSignatureMake(4, 4)
 *
 *  @param numerator   The numerator for the time signature, or number of beats per measure.
 *  @param denominator The denominator for the time signature, or fraction of a note per beat.
 *
 *  @return An MIKMIDITimeSignature struct.
 */
NS_INLINE MIKMIDITimeSignature MIKMIDITimeSignatureMake(UInt8 numerator, UInt8 denominator) {
	MIKMIDITimeSignature ts;
	ts.numerator = numerator;
	ts.denominator = denominator;
	return ts;
}

NS_ASSUME_NONNULL_BEGIN

/**
 *  A meta event containing time signature information.
 */
@interface MIKMIDIMetaTimeSignatureEvent : MIKMIDIMetaEvent

/**
 *  Initializes an MIKMIDIMetaTimeSignatureEvent with the specified time signature.
 *
 *  @param signature An MIKMIDITimeSignature value.
 *  @param timeStamp The time stamp for the event.
 *
 *  @return An initialized MIKMIDIMetaTimeSignatureEvent instance.
 */
- (instancetype)initWithTimeSignature:(MIKMIDITimeSignature)signature timeStamp:(MusicTimeStamp)timeStamp;

/**
 *  Initializes an MIKMIDIMetaTimeSignatureEvent with the specified time signature numerator and denominator.
 *
 *  Instances initialized with this initializer use the default values for metronomePulse (24)
 *  and thirtySecondsPerQuarterNote (8).
 *
 *  @param numerator   The numerator for the time signature, or number of beats per measure.
 *  @param denominator The denominator for the time signature, or fraction of a note per beat.
 *  @param timeStamp The time stamp for the event.
 *
 *  @return An initialized MIKMIDIMetaTimeSignatureEvent instance.
 */
- (instancetype)initWithNumerator:(UInt8)numerator denominator:(UInt8)denominator timeStamp:(MusicTimeStamp)timeStamp;

/**
 *  The numerator of the time signature.
 */
@property (nonatomic, readonly) UInt8 numerator;

/**
 *  The denominator of the time signature.
 */
@property (nonatomic, readonly) UInt8 denominator;

/**
 *  The number of MIDI clock ticks per metronome tick.
 */
@property (nonatomic, readonly) UInt8 metronomePulse;

/**
 *  The number of notated 32nd notes in a MIDI quarter note.
 */
@property (nonatomic, readonly) UInt8 thirtySecondsPerQuarterNote;

@end

/**
 *  The mutable counterpart of MIKMIDIMetaTimeSignatureEvent.
 */
@interface MIKMutableMIDIMetaTimeSignatureEvent : MIKMIDIMetaTimeSignatureEvent

@property (nonatomic, readwrite) MIKMIDIMetaEventType metadataType;
@property (nonatomic, strong, readwrite, null_resettable) NSData *metaData;
@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, readwrite) UInt8 numerator;
@property (nonatomic, readwrite) UInt8 denominator;
@property (nonatomic, readwrite) UInt8 metronomePulse;
@property (nonatomic, readwrite) UInt8 thirtySecondsPerQuarterNote;

@end

NS_ASSUME_NONNULL_END