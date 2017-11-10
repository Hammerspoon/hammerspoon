//
//  MIKMIDISequence.h
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDICompilerCompatibility.h"
#import "MIKMIDIMetaTimeSignatureEvent.h"

@class MIKMIDITrack;
@class MIKMIDISequencer;
@class MIKMIDIDestinationEndpoint;
@class MIKMIDIMetaTimeSignatureEvent;
@class MIKMIDITempoEvent;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Instances of MIKMIDISequence contain a collection of MIDI tracks. MIKMIDISequences may be thought
 *  of as MIDI "songs". They can be loaded from and saved to MIDI files. They can also be played
 *  using an MIKMIDISequencer.
 *
 *  @see MIKMIDITrack
 *  @see MIKMIDISequencer
 */
@interface MIKMIDISequence : NSObject

/**
 *  Creates and initializes a new instance of MIKMIDISequence.
 *
 *  @return A new instance of MIKMIDISequence, or nil if an error occured.
 */
+ (nullable instancetype)sequence;

/**
 *  Creates and initilazes a new instance of MIKMIDISequence from a MIDI file.
 *
 *  @param fileURL The URL of the MIDI file.
 *  @param error If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 *
 *  @return A new instance of MIKMIDISequence containing the loaded file's MIDI sequence, or nil if an error occured.
 */
+ (nullable instancetype)sequenceWithFileAtURL:(NSURL *)fileURL error:(NSError **)error;

/**
 *  Creates and initilazes a new instance of MIKMIDISequence from a MIDI file.
 *
 *  @param fileURL The URL of the MIDI file.
 *  @param convertMIDIChannelsToTracks Determines whether or not the track structure should be altered. When YES, the resulting sequence will
 *  contain a tempo track, 1 track for each MIDI Channel that is found in the MIDI file, and 1 track for SysEx or MetaEvents as the last track in
 *  the sequence. When NO, the track structure of the original MIDI file is left unaltered.
 *  @param error If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 *
 *  @return A new instance of MIKMIDISequence containing the loaded file's MIDI sequence, or nil if an error occured.
 */
+ (nullable instancetype)sequenceWithFileAtURL:(NSURL *)fileURL convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error;

/**
 *  Initilazes a new instance of MIKMIDISequence from a MIDI file.
 *
 *  @param fileURL The URL of the MIDI file.
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 *
 *  @return A new instance of MIKMIDISequence containing the loaded file's MIDI sequence, or nil if an error occured.
 */
- (nullable instancetype)initWithFileAtURL:(NSURL *)fileURL error:(NSError **)error;

/**
 *  Initilazes a new instance of MIKMIDISequence from a MIDI file.
 *
 *  @param fileURL The URL of the MIDI file.
 *  @param convertMIDIChannelsToTracks Determines whether or not the track structure should be altered. When YES, the resulting sequence will
 *  contain a tempo track, 1 track for each MIDI Channel that is found in the MIDI file, and 1 track for SysEx or MetaEvents as the last track in
 *  the sequence. When NO, the track structure of the original MIDI file is left unaltered.
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 *
 *  @return A new instance of MIKMIDISequence containing the loaded file's MIDI sequence, or nil if an error occured.
 */
- (nullable instancetype)initWithFileAtURL:(NSURL *)fileURL convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error;

/**
 *  Creates and initializes a new instance of MIKMIDISequence from MIDI data.
 *
 *  @param data  An NSData instance containing the data for the MIDI sequence/file.
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *
 *  @return If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 */
+ (nullable instancetype)sequenceWithData:(NSData *)data error:(NSError **)error;

/**
 *  Creates and initializes a new instance of MIKMIDISequence from MIDI data.
 *
 *  @param data  An NSData instance containing the data for the MIDI sequence/file.
 *  @param convertMIDIChannelsToTracks Determines whether or not the track structure should be altered. When YES, the resulting sequence will
 *  contain a tempo track, 1 track for each MIDI Channel that is found in the MIDI file, and 1 track for SysEx or MetaEvents as the last track in
 *  the sequence. When NO, the track structure of the original MIDI file is left unaltered.
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *
 *  @return If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 */
+ (nullable instancetype)sequenceWithData:(NSData *)data convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error;

/**
 *  Initializes a new instance of MIKMIDISequence from MIDI data.
 *
 *  @param data  An NSData instance containing the data for the MIDI sequence/file.
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *
 *  @return If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 */
- (nullable instancetype)initWithData:(NSData *)data error:(NSError **)error;

/**
 *  Initializes a new instance of MIKMIDISequence from MIDI data.
 *
 *  @param data  An NSData instance containing the data for the MIDI sequence/file.
 *  @param convertMIDIChannelsToTracks Determines whether or not the track structure should be altered. When YES, the resulting sequence will
 *  contain a tempo track, 1 track for each MIDI Channel that is found in the MIDI file, and 1 track for SysEx or MetaEvents as the last track in
 *  the sequence. When NO, the track structure of the original MIDI file is left unaltered.
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *
 *  @return If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 */
- (nullable instancetype)initWithData:(NSData *)data convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error;

/**
 *  Writes the MIDI sequence in Standard MIDI File format to a file at the specified URL.
 *
 *  @param fileURL The URL to write the MIDI file to.
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 *
 *  @return Whether or not the file write was successful.
 */
- (BOOL)writeToURL:(NSURL *)fileURL error:(NSError **)error;

#pragma mark - Track Management

/**
 *  Creates and adds a new MIDI track to the sequence.
 *
 *  @param error If an error occurs, upon return contains an NSError object that describes the problem. If you are not interested in possible errors,
 *  you may pass in NULL.
 *
 *  @return The newly created track, or nil if an error occurred.
 */
- (nullable MIKMIDITrack *)addTrackWithError:(NSError **)error;

/**
 *  Creates and adds a new MIDI track to the sequence. May return nil if an error occurs.
 *
 *  @deprecated: This method is deprecated. You should use -addTrackWithError: instead.
 */
- (nullable MIKMIDITrack *)addTrack DEPRECATED_ATTRIBUTE NS_SWIFT_UNAVAILABLE("Use the error throwing variant instead.");

/**
 *  Removes the specified MIDI track from the sequence.
 *
 *  @param track The track to remove.
 *
 *  @return Whether or not removing the track was successful.
 */
- (BOOL)removeTrack:(MIKMIDITrack *)track;

#pragma mark - Tempo & Time Signature

/**
 *  Returns an array of MIKMIDIEvent from the tempo track.
 *
 *  This is a convenience method, and is equivalent to calling -eventsOfClass:fromTimeStamp:toTimeStamp:
 *  on the tempo track with the parameters [MIKMIDIMetaTimeSignatureEvent class], 0, and kMusicTimeStamp_EndOfTrack respectively.
 *
 *  @return An array of MIKMIDIMetaTimeSignatureEvent.
 */
- (MIKArrayOf(MIKMIDIMetaTimeSignatureEvent *) *)timeSignatureEvents;

/**
 *  Returns an array of MIKMIDITempoEvent from the tempo track.
 *
 *  This is a convenience method, and is equivalent to calling -eventsOfClass:fromTimeStamp:toTimeStamp:
 *  on the tempo track with the parameters [MIKMIDITempoEvent class], 0, and kMusicTimeStamp_EndOfTrack respectively.
 *
 *  @return An array of MIKMIDITempoEvent.
 */
- (MIKArrayOf(MIKMIDITempoEvent *) *)tempoEvents;

/**
 *  Removes any existing tempo events and inserts a tempo event with the desired bpm at the beginning of the tempo track.
 *
 *  @param bpm The number of beats per minute for the new tempo.
 *
 *  @return Whether or not setting the tempo of the sequence was successful.
 */
- (BOOL)setOverallTempo:(Float64)bpm;

/**
 *  Inserts a tempo event with the desired tempo in beats per minute (BPM)
 *  into the tempo track at the specified time stamp.
 *
 *  @param bpm The number of beats per minute for the tempo.
 *  @param timeStamp The time stamp at which to set the tempo.
 *
 *  @return Whether or not setting the tempo of the sequence was succesful.
 */
- (BOOL)setTempo:(Float64)bpm atTimeStamp:(MusicTimeStamp)timeStamp;

/**
 *  Returns the tempo in beats per minute (BPM) of the last tempo event before 
 *  the specified time stamp.
 *
 *  @param timeStamp The time stamp at which you would like to know the sequence's tempo.
 *
 *  @return The tempo in beats per minute at the specified time stamp, or 0.0 if an error occurred.
 */
- (Float64)tempoAtTimeStamp:(MusicTimeStamp)timeStamp;

/**
 *  Sets the overall time signature for the receiver.
 *
 *  This method deletes all existing time signature events from the receiver's 
 *  tempo track, replacing them with a single event with the specified time signature.
 *
 *  @param signature An MIKMIDITimeSignature struct with the desired overall time signature.
 *
 *  @return YES if setting the overall time signature was succesful, NO if an error occurred.
 *
 *  @see -timeSignatureAtTimeStamp:
 *	@see -setTimeSignature:atTimeStamp:
 */
- (BOOL)setOverallTimeSignature:(MIKMIDITimeSignature)signature;

/**
 *  Sets the time signature of the receiver at a specified time.
 *
 *  Unlike -setOverallTimeSignature, this method does not modify any existing
 *  time signature events.
 *
 *  @param signature An MIKMIDITimeSignature struct representing the desired time signature.
 *  @param timeStamp The time stamp at which the time signature should be effective.
 *
 *  @return YES if setting the time signature was successful, NO if an error occurred.
 *
 *  @see -timeSignatureAtTimeStamp:
 *	@see -setOverallTimeSignature:
 */
- (BOOL)setTimeSignature:(MIKMIDITimeSignature)signature atTimeStamp:(MusicTimeStamp)timeStamp;

/**
 *  Returns the time signature in effect at the the specified time stamp.
 *
 *  @param timeStamp The time stamp at which you would like to know the receiver's time signature.
 *
 *  @return An MIKMIDITimeSignature struct representing the time signature of the sequence at
 *  the specified time stamp. Defaults to 4/4 if no time signature events are found.
 *
 *  @see -timeSignatureAtTimeStamp:
 *	@see -setOverallTimeSignature:
 */
- (MIKMIDITimeSignature)timeSignatureAtTimeStamp:(MusicTimeStamp)timeStamp;

#pragma mark - Properties

/**
 *	The sequencer this sequence is assigned to for playback.
 */
@property (nonatomic, weak, readonly, nullable) MIKMIDISequencer *sequencer;

/**
 *  The tempo track for the sequence. Even in a new, empty sequence,
 *  this will return a tempo track to which tempo events can be added.
 */
@property (nonatomic, readonly) MIKMIDITrack *tempoTrack;

/**
 *  The MIDI music tracks for the sequence. An array of MIKMIDITrack instances.
 *  Does not include the tempo track.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDITrack *) *tracks;

/**
 *  The underlying MusicSequence that backs the instance of MIKMIDISequence.
 */
@property (nonatomic, readonly) MusicSequence musicSequence;

/**
 *  The length of the sequence as a MusicTimeStamp.
 *
 *  Set to MIKMIDISequenceLongestTrackLength to make the length equal to the length of the longest track.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic) MusicTimeStamp length;

/**
 *  The duration of the sequence in seconds.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic, readonly) Float64 durationInSeconds;

/**
 *  The MIDI data that composes the sequence. This data is equivalent to an NSData representation of a standard MIDI file.
 */
@property (nonatomic, readonly, nullable) NSData *dataValue;

/**
 *  A block to be called for each user event added to any music track owned by the sequence.
 *
 *  This block is to be used in the same fashion as you would use the callback function sent to
 *  MusicSequenceSetUserCallback() if you were working directly with CoreMIDI.
 */
@property (copy, nonatomic) void (^callBackBlock)(MIKMIDITrack *track, MusicTimeStamp eventTime, const MusicEventUserData *eventData, MusicTimeStamp startSliceBeat, MusicTimeStamp endSliceBeat);

#pragma mark - Deprecated

/**
 *  @deprecated This method is deprecated. Use +sequenceWithData:error: instead.
 *
 *  Creates and initializes a new instance of MIKMIDISequence from MIDI data.
 *
 *  @param data The MIDI data for the new sequence.
 *
 *  @return A new instance of MIKMIDISequence containing the MIDI data, or nil if an error occured.
 */
+ (nullable instancetype)sequenceWithData:(NSData *)data DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated This method is deprecated. Use -initWithData:error: instead.
 *
 *  Initializes a new instance of MIKMIDISequence from MIDI data.
 *
 *  @param data The MIDI data for the new sequence.
 *
 *  @return A new instance of MIKMIDISequence containing the MIDI data, or nil if an error occured.
 */
- (nullable instancetype)initWithData:(NSData *)data DEPRECATED_ATTRIBUTE;

/**
 *	@deprecated This method is deprecated. Use -[MIKMIDISequencer 
 *	setDestinationEndpoint:forTrack:] instead.
 *
 *  Sets the destination endpoint for each track in the sequence.
 *
 *  @param destinationEndpoint The destination endpoint to set for each track in the sequence.
 */
- (void)setDestinationEndpoint:(nullable MIKMIDIDestinationEndpoint *)destinationEndpoint DEPRECATED_ATTRIBUTE;

/**
 *	@deprecated This method has been replaced by -tempoAtTimeStamp: and simply calls through to that method.
 *  You should not call it, and should update your code to call -timeSignatureAtTimeStamp: instead.
 *
 *  @param bpm On output, the beats per minute of the tempo at the specified time stamp.
 *  @param timeStamp The time stamp that you would like to know the sequence's tempo at.
 *  @return YES if getting the tempo was successful, NO if an error occurred.
 */
- (BOOL)getTempo:(Float64 *)bpm atTimeStamp:(MusicTimeStamp)timeStamp DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated This method has been replaced by -timeSignatureAtTimeStamp: and simply calls through to that method.
 *  You should not call it, and should update your code to call -timeSignatureAtTimeStamp: instead.
 *
 *  @param signature On output, a time signature instance with its values populated.
 *  @param timeStamp The time stamp at which you would like to know the time signature.
 *  @return YES if getting the time signature was successful, NO if an error occurred.
 */
- (BOOL)getTimeSignature:(MIKMIDITimeSignature *)signature atTimeStamp:(MusicTimeStamp)timeStamp DEPRECATED_ATTRIBUTE;

/**
 *	@deprecated This method is only useful in the context of using a sequence in MIKMIDIPlayer, which has been deprecated.
 *
 *  A MusicTimeStamp that is less than the sequence's length, but is at an equivalent position in the looped sequence as loopedTimeStamp
 *
 *  When the music sequence is being looped by an MIKMIDIPlayer, the time stamp of the player continuosly increases. This method can be
 *  used to find where in the MIDI sequence the looped playback is at. For example, in a sequence with a length of 16,
 *  calling this method with a loopedTimeStamp of 17 would return 1.
 *
 *  @param loopedTimeStamp The time stamp that you would like an equivalent time stamp for.
 *
 *  @return The MusicTimeStamp of the sequence that is in an equivalent position in the sequence as loopedTimeStamp.
 */
- (MusicTimeStamp)equivalentTimeStampForLoopedTimeStamp:(MusicTimeStamp)loopedTimeStamp DEPRECATED_ATTRIBUTE;


@end

FOUNDATION_EXPORT const MusicTimeStamp MIKMIDISequenceLongestTrackLength;

NS_ASSUME_NONNULL_END
