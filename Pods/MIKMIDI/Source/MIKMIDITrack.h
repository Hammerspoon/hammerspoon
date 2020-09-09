//
//  MIKMIDITrack.h
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDISequence;
@class MIKMIDIEvent;
@class MIKMIDINoteEvent;
@class MIKMIDIDestinationEndpoint;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Instances of MIKMIDITrack contain sequences of MIDI events. Commonly,
 *  these will be MIDI notes. Multiple MIKMIDITracks can be contained in a
 *  MIKMIDISequence, which can be played.
 *  
 *  @see MIKMIDISequence
 */
@interface MIKMIDITrack : NSObject

/**
 *  Inserts the specified MIDI event into the receiver.
 *
 *  @param event The MIDI event to insert into the track.
 */
- (void)addEvent:(MIKMIDIEvent *)event;

/**
 *   Inserts the specified MIDI events into the receiver.
 *
 *  @param events An NSArray containing the events to be added.
 */
- (void)addEvents:(MIKArrayOf(MIKMIDIEvent *) *)events;

/**
 *  Removes the specified MIDI event from the receiver.
 *
 *  @param event The MIDI event to remove from the track.
 */
- (void)removeEvent:(MIKMIDIEvent *)event;

/**
 *  Removes the specified MIDI events from the receiver.
 *
 *  @param events An NSArray containing the events to be removed.
 */
- (void)removeEvents:(MIKArrayOf(MIKMIDIEvent *) *)events;

/**
 *  Removes all MIDI events from the receiver.
 */
- (void)removeAllEvents;

/**
 *  Gets all of the MIDI events in the track starting from startTimeStamp and ending at endTimeStamp inclusively.
 *
 *  @param startTimeStamp The starting time stamp for the range to get MIDI events for.
 *  @param endTimeStamp The ending time stamp for the range to get MIDI events for. Use kMusicTimeStamp_EndOfTrack to get events up to the
 *  end of the track.
 *
 *  @return An array of MIKMIDIEvent.
 */
- (MIKArrayOf(MIKMIDIEvent *) *)eventsFromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp;

/**
 *  Gets all of the MIDI events of a specific class in the track starting from startTimeStamp and ending at endTimeStamp inclusively.
 *
 *  @param eventClass The class of MIDI events you would like to retrieve. This class must be the MIKMIDIEvent class or a subclass thereof.
 *  @param startTimeStamp The staring time stamp for the range to get MIDI events for.
 *  @param endTimeStamp The ending time stamp for the range to get MIDI events for. Use kMusicTimeStamp_EndOfTrack to get events up to the
 *  end of the track.
 *
 *  @return An array of specified class of MIDI events.
 */
- (MIKArrayOfKindOf(MIKMIDIEvent *) *)eventsOfClass:(nullable Class)eventClass fromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp;

/**
 *  Gets all of the MIDI notes in the track starting from startTimeStamp and ending at endTimeStamp inclusively.
 *
 *  @param startTimeStamp The starting time stamp for the range to get MIDI events for.
 *  @param endTimeStamp The ending time stamp for the range to get MIDI notes for. Use kMusicTimeStamp_EndOfTrack to get events up to the
 *  end of the track.
 *
 *  @return An array of MIKMIDINoteEvent instances.
 *
 *  @discussion Calling this method is equivalent to calling eventsOfClass:fromTimeStamp:toTimeStamp: with [MIKMIDINoteEvent class].
 */
- (MIKArrayOf(MIKMIDINoteEvent *) *)notesFromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp;

#pragma mark - Event Manipulation

/**
 *  Moves all of the MIDI events between startTimeStamp and endTimeStamp inclusively by the specified offset.
 *
 *  @param startTimeStamp The starting time stamp for the range of the events to move.
 *  @param endTimeStamp The ending time stamp for the range of the events to move.
 *  @param timestampOffset The amount to move the events
 *
 *  @return Whether or not moving the events was succesful.
 */
- (BOOL)moveEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp byAmount:(MusicTimeStamp)timestampOffset;

/**
 *  Removes all of the MIDI events between startTimeStamp and endTimeStamp inclusively.
 *
 *  @param startTimeStamp The starting time stamp for the range of the events to remove.
 *  @param endTimeStamp The ending time stamp for the range of the events to move.
 *
 *  @return Whether or not moving the MIDI events was succesful.
 */
- (BOOL)clearEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp;

/**
 *  Removes all of the MIDI events between startTimeStamp and endTimeStamp inclusively. Events that fall past the
 *  specified range will be moved back by the specified range time.
 *
 *  @param startTimeStamp The starting time stamp for the range of the events to cut.
 *  @param endTimeStamp The ending time stamp for the range of the events to cut.
 *
 *  @return Whether or not cutting the MIDI events was succesful.
 */
- (BOOL)cutEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp;

/**
 *  Copies MIDI events from one track and inserts them into the receiver.
 *
 *  @param origTrack The track to copy the events from.
 *  @param startTimeStamp The starting time stamp for the range of the events to copy.
 *  @param endTimeStamp The ending time stamp for the range of the events to copy.
 *  @param destTimeStamp The time stamp at which to the copied events will be inserted into the receiver.
 *
 *  @return Whether or not copying the MIDI events was succesful.
 */
- (BOOL)copyEventsFromMIDITrack:(MIKMIDITrack *)origTrack fromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp andInsertAtTimeStamp:(MusicTimeStamp)destTimeStamp;

/**
 *  Copies MIDI events from one track and merges them into the receiver.
 *
 *  @param origTrack The track to copy the events from.
 *  @param startTimeStamp The starting time stamp for the range of the events to copy.
 *  @param endTimeStamp The ending time stamp for the range of the events to copy.
 *  @param destTimeStamp The time stamp at which to the copied events will be merged into the receiver.
 *
 *  @return Whether or not merging the MIDI events was succesful.
 */
- (BOOL)mergeEventsFromMIDITrack:(MIKMIDITrack *)origTrack fromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp atTimeStamp:(MusicTimeStamp)destTimeStamp;

/**
 *  The MIDI sequence the track belongs to.
 */
@property (weak, nonatomic, readonly, nullable) MIKMIDISequence *sequence;

/**
 *  The underlying MusicTrack that backs the instance of MIKMIDITrack.
 */
@property (nonatomic, readonly) MusicTrack musicTrack;

/**
 *  An array of MIKMIDIEvent containing all of the MIDI events for the track, sorted by timestamp.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic, copy) MIKArrayOf(MIKMIDIEvent *) *events;

/**
 *  An array of MIKMIDINoteEvent containing all of the MIDI note events for the track, sorted by timestamp.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDINoteEvent *) *notes;

/**
 *  The receiver's index in its containing sequence, or -1 if the track isn't in a sequence.
 */
@property (nonatomic, readonly) NSInteger trackNumber;

/**
 *  A MIDI track’s start time in terms of beat number. By default this value is 0.
 *
 *  This can be used to offset playback by MIKMIDISequencer of individual tracks in a sequence.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic) MusicTimeStamp offset;

/**
 *  Whether or not the MIDI track is muted. Muted tracks are not played by MIKMIDISequencer.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic, getter = isMuted) BOOL muted;

/**
 *  Whether or not the MIDI track is soloed.
 *
 *  If a track is muted, it is not played by MIKMIDISequencer, and its solo status is ignored.
 *  If any non-muted tracks in a sequence have this property set to YES, MIKMIDISequencer will only play those,
 *  and will not play the non-solo tracks. If this is set to NO for all non-muted tracks, then
 *  all non-muted tracks will be played.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic, getter = isSolo) BOOL solo;

/**
 *  The length of the MIDI track.
 *
 *  This property can be observed using Key Value Observing. 
 *
 *	@note This property will automatically get updated whenever the tracks events are changed.
 */
@property (nonatomic) MusicTimeStamp length;

/**
 *  The time resolution for a sequence of MIDI events. For example, this value can indicate the time resolution that was specified
 *  by the MIDI file used to construct a sequence.
 *
 *  If you create a MIDI sequence programmatically, the value is set to 480. If you create a MIDI sequence from a MIDI file,
 *  the value is set to the time resolution specified in the MIDI file.
 */
@property (nonatomic, readonly) SInt16 timeResolution;

#pragma mark - Deprecated

/**
 *  @deprecated This method only affects playback using MIKMIDIPlayer. Use `-[MIKMIDISequencer isLooping]` instead.
 *
 *  Whether the track is set to loop.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic, readonly) BOOL doesLoop DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated This method only affects playback using MIKMIDIPlayer. Use `MIKMIDISequencer` looping API instead.
 *
 *	The number of times to play the designated portion of the music track. By default, a music track plays once.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic) SInt32 numberOfLoops DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated This method only affects playback using MIKMIDIPlayer.
 *  Use `-[MIKMIDISequencer setLoopStartTimeStamp:endTimeStamp:]`, and associated properties instead.
 *
 *  The point in a MIDI track, measured in beats from the end of the MIDI track, at which to begin playback during looped playback.
 *  That is, during looped playback, a MIDI track plays from (length – loopDuration) to length.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic) MusicTimeStamp loopDuration DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated This method only affects playback using MIKMIDIPlayer. Use `MIKMIDISequencer` looping API instead.
 *
 *  The loop info for the track.
 *
 *  This property can be observed using Key Value Observing.
 */
@property (nonatomic) MusicTrackLoopInfo loopInfo DEPRECATED_ATTRIBUTE;

/**
 *	@deprecated This method is deprecated. Use -trackNumber instead.
 *
 *  Gets the track's track number in it's owning MIDI sequence.
 *
 *  @param trackNumber On output, the track number of the track.
 *
 *  @return Whether or not getting the track number was succesful.
 */
- (BOOL)getTrackNumber:(UInt32 *)trackNumber DEPRECATED_ATTRIBUTE;

/**
 *	@deprecated This property has been deprecated. Use -[MIKMIDISequencer setDestinationEndpoint:forTrack:] instead.
 *  
 *	The destination endpoint for the MIDI events of the track during playback.
 */
@property (nonatomic, strong, readwrite, nullable) MIKMIDIDestinationEndpoint *destinationEndpoint DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated Use -addEvent: instead.
 *
 *  Inserts the specified MIDI event into the track.
 *
 *  @param event The MIDI event to insert into the track.
 *
 *  @return Whether or not inserting the MIDI event was succesful.
 */
- (BOOL)insertMIDIEvent:(MIKMIDIEvent *)event DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated Use -addEvent: instead.
 *
 *  Inserts MIDI events into the track.
 *
 *  @param events An NSSet of MIKMIDIEvent to insert into the track.
 *
 *  @return Whether or not inserting the MIDI events was succesful.
 */
- (BOOL)insertMIDIEvents:(MIKSetOf(MIKMIDIEvent *) *)events DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated Use -removeEvent: instead.
 *
 *  Removes MIDI events from a track.
 *
 *  @param events An NSSet of MIKMIDIEvent to remove from the track.
 *
 *  @return Whether or not removing the MIDI events was succesful.
 */
- (BOOL)removeMIDIEvents:(MIKSetOf(MIKMIDIEvent *) *)events DEPRECATED_ATTRIBUTE;

/**
 *  @deprecated Use -removeAllEvents instead.
 *
 *  Removes all MIDI events from the track.
 *
 *  @return Whether or not removing all of the MIDI events from the track was succesful.
 */
- (BOOL)clearAllEvents DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
