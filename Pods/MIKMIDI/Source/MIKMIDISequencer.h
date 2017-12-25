//
//  MIKMIDISequencer.h
//  MIKMIDI
//
//  Created by Chris Flesner on 11/26/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDISequence;
@class MIKMIDITrack;
@class MIKMIDIMetronome;
@class MIKMIDICommand;
@class MIKMIDIDestinationEndpoint;
@class MIKMIDISynthesizer;
@class MIKMIDIClock;
@protocol MIKMIDICommandScheduler;

/**
 *  Types of click track statuses, that determine when the click track will be audible.
 *
 *  @see clickTrackStatus
 */
typedef NS_ENUM(NSInteger, MIKMIDISequencerClickTrackStatus) {
	/** The click track will not be heard during playback or recording. */
	MIKMIDISequencerClickTrackStatusDisabled,
	/** The click track will only be heard while recording. */
	MIKMIDISequencerClickTrackStatusEnabledInRecord,
	/** The click track will only be heard while recording and while the playback position is still in the pre-roll. */
	MIKMIDISequencerClickTrackStatusEnabledOnlyInPreRoll,
	/** The click track will always be heard during playback and recording. */
	MIKMIDISequencerClickTrackStatusAlwaysEnabled
};

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDISequencer can be used to play and record to an MIKMIDISequence.
 *
 *  @note Recording and using the click track may not yet be fully functional, and should
 *	be considered experimental in the meantime. Please submit issues and/or pull requests
 *	when you find areas that don't work as expected.
 */
@interface MIKMIDISequencer : NSObject

#pragma mark - Creation

/**
 *  Convenience method for creating a new MIKMIDISequencer instance with an empty sequence.
 *
 *  @return An initialized MIKMIDISequencer.
 */
+ (instancetype)sequencer;

/**
 *  Initializes and returns  a new MIKMIDISequencer ready to playback and record to the
 *  specified sequence.
 *
 *  @param sequence The sequence to playback and record to.
 *
 *  @return An initialized MIKMIDISequencer.
 */
- (instancetype)initWithSequence:(MIKMIDISequence *)sequence;

/**
 *  Convenience method for creating a new MIKMIDISequencer ready to playback and
 *  record to the specified sequence.
 *
 *  @param sequence The sequence to playback and record to.
 *
 *  @return An initialized MIKMIDISequencer.
 */
+ (instancetype)sequencerWithSequence:(MIKMIDISequence *)sequence;

#pragma mark - Playback

/**
 *  Starts playback from the beginning of the sequence.
 */
- (void)startPlayback;

/**
 *  Starts playback from the specified time stamp.
 *
 *  @param timeStamp The position in the sequence to begin playback from.
 */
- (void)startPlaybackAtTimeStamp:(MusicTimeStamp)timeStamp;

/**
 *  Starts playback from the specified MusicTimeStamp at the specified MIDITimeStamp.
 *  This could be useful if you need to synchronize the playback with another source
 *  such as an audio track, or another MIKMIDISequencer instance.
 *
 *  @param timeStamp The position in the sequence to begin playback from.
 *  @param midiTimeStamp The MIDITimeStamp to begin playback at.
 */
- (void)startPlaybackAtTimeStamp:(MusicTimeStamp)timeStamp MIDITimeStamp:(MIDITimeStamp)midiTimeStamp;

/**
 *  Starts playback from the position returned by -currentTimeStamp.
 *
 *  @see currentTimeStamp
 */
- (void)resumePlayback;

/**
 *  Stops all playback and recording.
 */
- (void)stop;

/**
 *	Sends any pending note offs for the command scheduler immeidately.
 *	This can be useful if you are changing the notes in the MIDI track and
 *	you want the old notes to immediately stop rather than play until their
 *	original end time stamp.
 */
- (void)stopAllPlayingNotesForCommandScheduler:(id<MIKMIDICommandScheduler>)scheduler;

/**
 *	Allows subclasses to modify the MIDI commands that are about to be
 *	scheduled with a command scheduler.
 *
 *	@param commandsToBeScheduled An array of MIKMIDICommands that are about
 *	to be scheduled.
 *
 *	@param scheduler The command scheduler the commands will be scheduled with
 *	after they are modified.
 *
 *	@note You should not call this method directly. It is made public solely to
 *	give subclasses a chance to alter or override any MIDI commands parsed from the
 *	MIDI sequence before they get sent to their destination endpoint.
 *
 */
- (MIKArrayOf(MIKMIDICommand *) *)modifiedMIDICommandsFromCommandsToBeScheduled:(MIKArrayOf(MIKMIDICommand *) *)commandsToBeScheduled forCommandScheduler:(id<MIKMIDICommandScheduler>)scheduler;

/**
 *	Sets the loopStartTimeStamp and loopEndTimeStamp properties.
 *
 *	@param loopStartTimeStamp The MusicTimeStamp to begin looping at.
 *
 *	@param loopEndTimeStamp The MusicTimeStamp to end looping at. To have
 *	the loop end at the end of the sequence, regardless of sequence length, 
 *	pass in MIKMIDISequencerEndOfSequenceLoopEndTimeStamp.
 *
 *	@see loopStartTimeStamp
 *	@see loopEndTimeStamp
 *	@see loop
 *	@see looping
 */
- (void)setLoopStartTimeStamp:(MusicTimeStamp)loopStartTimeStamp endTimeStamp:(MusicTimeStamp)loopEndTimeStamp;


#pragma mark - Recording

/**
 *  Starts playback from the beginning of the sequence minus the value returned
 *  by -preRoll, and enables recording of incoming events to the record enabled tracks.
 *
 *  @see preRoll
 *  @see recordEnabledTracks
 */
- (void)startRecording;

/**
 *  Starts playback from the specified time stamp minus the value returned by
 *  -preRoll, and enables recording of incoming events to the record enabled tracks.
 *
 *  @see preRoll
 *  @see recordEnabledTracks
 */
- (void)startRecordingAtTimeStamp:(MusicTimeStamp)timeStamp;

/**
 *  Starts playback from the specified MusicTimeStamp minus the value returned by -preRoll
 *  at the specified MIDITimeStamp, and enables recording of incoming events to the
 *  record enabled tracks.
 *
 *  @see preRoll
 *  @see recordEnabledTracks
 */
- (void)startRecordingAtTimeStamp:(MusicTimeStamp)timeStamp MIDITimeStamp:(MIDITimeStamp)midiTimeStamp;

/**
 *  Starts playback from the position returned by -currentTimeStamp minus the
 *  value returned by -preRoll, and enables recording of incoming events to the
 *  record enabled tracks.
 *
 *  @see preRoll
 *  @see recordEnabledTracks
 */
- (void)resumeRecording;

/**
 *  Records a MIDI command to the record enabled tracks.
 *
 *  @param command The MIDI command to record to the record enabled tracks.
 *
 *  @note When recording is NO, calls to this method will do nothing.
 *
 *  @see recording
 *  @see recordEnabledTracks
 */
- (void)recordMIDICommand:(MIKMIDICommand *)command;

#pragma mark - Configuration

/**
 *  Sets the command scheduler for a track in the sequencer's sequence.
 *  Calling this method is optional. By default, the sequencer will setup internal synthesizers
 *	so that playback "just works".
 *
 *  @note If track is not contained by the receiver's sequence, this method does nothing.
 *
 *  @param commandScheduler	An object that conforms to MIKMIDICommandScheduler with which events
 *	in track should be scheduled during playback. MIKMIDIDestinationEndpoint and MIKMIDISynthesizer both conform to MIKMIDICommandScheduler, so they can be used here. Pass nil to remove an existing command scheduler.
 *  @param track	An MIKMIDITrack instance.
 */
- (void)setCommandScheduler:(nullable id<MIKMIDICommandScheduler>)commandScheduler forTrack:(MIKMIDITrack *)track;

/**
 *  Returns the command scheduler for a track in the sequencer's sequence.
 *
 *  MIKMIDISequencer will automatically create its own default synthesizers connected 
 *	for any tracks not configured manually. This means that even if you haven't called
 *	-setCommandScheduler:forTrack:, you can use this method to retrieve
 *  the default command scheduler for a given track.
 *
 *  @note If track is not contained by the receiver's sequence, this method returns nil.
 *
 *  @param track An MIKMIDITrack instance.
 *
 *  @return The command scheduler associated with track, or nil if one can't be found.
 *
 *  @see -setCommandScheduler:forTrack:
 *  @see -builtinSynthesizerForTrack:
 *	@see createSynthsIfNeeded
 */
- (nullable id<MIKMIDICommandScheduler>)commandSchedulerForTrack:(MIKMIDITrack *)track;

/**
 *  Returns synthesizer the receiver will use to synthesize MIDI during playback
 *  for any tracks whose MIDI has not been routed to a custom scheduler using
 *  -setCommandScheduler:forTrack:. For tracks where a custom scheduler has
 *  been set, this method returns nil.
 *
 *  The caller is free to reconfigure the synthesizer(s) returned by this method,
 *  e.g. to load a custom soundfont file or select a different instrument.
 *
 *  @param track The track for which the builtin synthesizer is desired.
 *
 *  @return An MIKMIDISynthesizer instance, or nil if a builtin synthesizer for track doesn't exist.
 */
- (nullable MIKMIDISynthesizer *)builtinSynthesizerForTrack:(MIKMIDITrack *)track;

#pragma mark - Properties

/**
 *  The sequence to playback and record to.
 */
@property (nonatomic, strong) MIKMIDISequence *sequence;

/**
 *	Whether or not the sequencer is currently playing. This can be observed with KVO.
 *
 *  @see recording
 */
@property (readonly, nonatomic, getter=isPlaying) BOOL playing;

/**
 *  Whether or not the sequence is currently playing and is record enabled.
 *  This can be observed with KVO.
 *
 *  @note When recording is YES, events will only be recorded to the tracks
 *  specified by -recordEnabledTracks.
 *
 *  @see playing
 *  @see recordEnabledTracks
 */
@property (readonly, nonatomic, getter=isRecording) BOOL recording;

/**
 *  The tempo the sequencer should play its sequence at. When set to 0, the sequence will be played using 
 *  the tempo events from the sequence's tempo track. Default is 0.
 */
@property (nonatomic) Float64 tempo;

/**
 *  The length the that the sequencer should consider its sequence to be. When set to 0, the sequencer
 *  will use sequence.length instead.
 *
 *  This can be handy if you want to alter the duration of playback to be shorter or longer
 *  than the sequence's length without affecting the sequence itself.
 */
@property (nonatomic) MusicTimeStamp overriddenSequenceLength;

/**
 *  The current playback position in the sequence.
 *
 *  @note This property is *not* observable using Key Value Observing.
 */
@property (nonatomic) MusicTimeStamp currentTimeStamp;


/**
 *  The amount of time (in beats) to pre-roll the sequence before recording.
 *  For example, if preRoll is set to 4 and you begin recording, the sequence
 *  will start 4 beats ahead of the specified recording position.
 *
 *  The default is 4.
 */
@property (nonatomic) MusicTimeStamp preRoll;

/**
 *  Whether or not playback should loop when between loopStartTimeStamp and loopEndTimeStamp.
 *
 *  @see loopStartTimeStamp
 *  @see loopEndTimeStamp
 *  @see looping
 */
@property (nonatomic, getter=shouldLoop) BOOL loop;

/**
 *  Whether or not playback is currently looping between loopStartTimeStamp and loopEndTimeStamp.
 *
 *  @note If loop is YES, and playback starts before loopStartTimeStamp, looping will be NO until
 *  currentTimeStamp reaches loopStartTimeStamp. At that point, looped playback will begin and
 *  the looping property will become YES. Conversely, if playback starts after loopEndTimeStamp,
 *  then the looped area of playback will never be reached and looping will remain NO.
 *
 *  @see loop
 *  @see loopStartTimeStamp
 *  @see loopEndTimeStamp
 *	@see -setLoopStartTimeStamp:loopEndTimeStamp:
 *  @see currentTimeStamp
 */
@property (readonly, nonatomic, getter=isLooping) BOOL looping;

/**
 *  The loop's beginning time stamp during looped playback.
 *
 *	@see -setLoopStartTimeStamp:loopEndTimeStamp:
 */
@property (readonly, nonatomic) MusicTimeStamp loopStartTimeStamp;

/**
 *  The loop's ending time stamp during looped playback, or MIKMIDISequencerEndOfSequenceLoopEndTimeStamp.
 *
 *	@note When this is set to MIKMIDISequencerEndOfSequenceLoopEndTimeStamp
 *	the loopEndTimeStamp will be treated as if it is set to the length of the
 *	sequence. The default is MIKMIDISequencerEndOfSequenceLoopEndTimeStamp.
 *
  *	@see effectiveLoopEndTimeStamp
 *	@see -setLoopStartTimeStamp:loopEndTimeStamp:
 */
@property (readonly, nonatomic) MusicTimeStamp loopEndTimeStamp;

/**
 *	The loop's ending time stamp during looped playback.
 *
 *	@note When loopEndTimeStamp is set to MIKMIDISequencerEndOfSequenceLoopEndTimeStamp,
 *	this will return the same length as the sequence.length. Otherwise loopEndTimeStamp
 *	will be returned.
 */
@property (readonly, nonatomic) MusicTimeStamp effectiveLoopEndTimeStamp;


/**
 *	Whether or not the sequencer should create synthesizers and endpoints
 *	for MIDI tracks that are not assigned an endpoint.
 *
 *	When this property is YES, -commandSchedulerForTrack: will create a 
 *	synthesizer for any track that has MIDI commands scheduled for it
 *	and doesn't already have an assigned scheduler. The default for this property
 *	is YES.
 *
 *	@see -commandSchedulerForTrack:
 */
@property (nonatomic, getter=shouldCreateSynthsIfNeeded) BOOL createSynthsIfNeeded;

/**
 *  The metronome to send click track events to.
 */
@property (nonatomic, strong, nullable) MIKMIDIMetronome *metronome;

/**
 *  When the click track should be heard.
 *  The default is MIKMIDISequencerClickTrackStatusEnabledInRecord.
 */
@property (nonatomic) MIKMIDISequencerClickTrackStatus clickTrackStatus;

/**
 *  The tracks to record incoming MIDI events to while recording is enabled.
 *
 *  Each incoming event is added to every track in this set.
 *
 *  @see recording
 *
 */
@property (nonatomic, copy, nullable) MIKSetOf(MIKMIDITrack *) *recordEnabledTracks;

/**
 *  An MIKMIDIClock that is synced with the sequencer's internal clock.
 *
 *  @  @see -[MIKMIDIClock syncedClock]
 */
@property (nonatomic, readonly) MIKMIDIClock *syncedClock;


/**
 *  The latest MIDITimeStamp the sequencer has looked ahead to to schedule MIDI events.
 */
@property (nonatomic, readonly) MIDITimeStamp latestScheduledMIDITimeStamp;


/**
 *	The maximum amount the sequencer will look ahead to schedule MIDI events. (0.05 to 1s).
 *
 *	The default of 0.1s should suffice for most uses. You may however, need a longer time
 *	if your sequencer needs to playback on iOS while the device is locked.
 */
@property (nonatomic) NSTimeInterval maximumLookAheadInterval;

#pragma mark - Deprecated

/**
 *	@deprecated Use -setCommandScheduler:forTrack: instead.
 *
 *  Sets the destination endpoint for a track in the sequencer's sequence.
 *  Calling this method is optional. By default, the sequencer will setup internal default endpoints
 *  connected to synthesizers so that playback "just works".
 *
 *  @note If track is not contained by the receiver's sequence, this method does nothing.
 *
 *  @param endpoint The MIKMIDIDestinationEndpoint instance to which events in track should be sent during playback.
 *  @param track    An MIKMIDITrack instance.
 */
- (void)setDestinationEndpoint:(MIKMIDIDestinationEndpoint *)endpoint forTrack:(MIKMIDITrack *)track __attribute((deprecated("use -setCommandScheduler:forTrack: instead")));

/**
 *	@deprecated Use -commandSchedulerForTrack: instead.
 *
 *  Returns the destination endpoint for a track in the sequencer's sequence.
 *
 *  MIKMIDISequencer will automatically create its own default endpoints connected to
 *  MIKMIDISynthesizers for any tracks not configured manually. This means that even if you
 *  haven't called -setDestinationEndpoint:forTrack:, you can use this method to retrieve
 *  the default endpoint for a given track.
 *
 *  @note If track is not contained by the receiver's sequence, this method returns nil.
 *
 *  @param track An MIKMIDITrack instance.
 *
 *  @return The destination endpoint associated with track, or nil if one can't be found.
 *
 *  @see -setDestinationEndpoint:forTrack:
 *  @see -builtinSynthesizerForTrack:
 *	@see createSynthsAndEndpointsIfNeeded
 */
- (nullable MIKMIDIDestinationEndpoint *)destinationEndpointForTrack:(MIKMIDITrack *)track __attribute((deprecated("use -setCommandScheduler:forTrack: instead")));

@end


/**
 *  Sent out shortly before playback loops.
 */
FOUNDATION_EXPORT NSString * const MIKMIDISequencerWillLoopNotification;

/**
 *	Set loopEndTimeStamp to this to have the loop end at the end of the
 *	sequence regardless of sequence length.
 */
FOUNDATION_EXPORT const MusicTimeStamp MIKMIDISequencerEndOfSequenceLoopEndTimeStamp;

NS_ASSUME_NONNULL_END