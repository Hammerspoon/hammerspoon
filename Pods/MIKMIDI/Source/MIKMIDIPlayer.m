//
//  MIKMIDIPlayer.m
//  MIKMIDI
//
//  Created by Chris Flesner on 9/8/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPlayer.h"
#import "MIKMIDITrack.h"
#import "MIKMIDITrack_Protected.h"
#import "MIKMIDISequence.h"
#import "MIKMIDIMetronome.h"
#import "MIKMIDIEvent.h"
#import "MIKMIDINoteEvent.h"
#import "MIKMIDIClientDestinationEndpoint.h"
#import "MIKMIDITempoEvent.h"
#import "MIKMIDIMetaTimeSignatureEvent.h"

#if !__has_feature(objc_arc)
#error MIKMIDIPlayer.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIPlayer.m in the Build Phases for this target
#endif

@interface MIKMIDIPlayer ()

@property (nonatomic) MusicPlayer musicPlayer;
@property (nonatomic) BOOL isPlaying;

@property (strong, nonatomic) NSNumber *lastStoppedAtTimeStampNumber;

@property (strong, nonatomic) NSDate *lastPlaybackStartedTime;

@property (strong, nonatomic) MIKMIDIPlayer *clickPlayer;
@property (nonatomic) BOOL isClickPlayer;
@property (strong, nonatomic) MIKMIDIClientDestinationEndpoint *metronomeEndpoint;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation MIKMIDIPlayer
#pragma clang diagnostic pop

#pragma mark - Lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        MusicPlayer musicPlayer;
        OSStatus err = NewMusicPlayer(&musicPlayer);
        if (err) {
            NSLog(@"NewMusicPlayer() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            return nil;
        }

        self.musicPlayer = musicPlayer;
		self.stopPlaybackAtEndOfSequence = YES;
		self.maxClickTrackTimeStamp = 480;
    }
    return self;
}

- (void)dealloc
{
    if (self.isPlaying) [self stopPlayback];

    OSStatus err = DisposeMusicPlayer(_musicPlayer);
    if (err) NSLog(@"DisposeMusicPlayer() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
}

#pragma mark - Playback

- (void)preparePlayback
{
    OSStatus err = MusicPlayerPreroll(self.musicPlayer);
    if (err) NSLog(@"MusicPlayerPreroll() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
}

- (void)startPlayback
{
    [self startPlaybackFromPosition:0];
}

- (void)startPlaybackFromPosition:(MusicTimeStamp)position
{
    if (self.isPlaying) [self stopPlayback];

    [self loopTracksWhenNeeded];
	[self addClickTrackWhenNeededFromTimeStamp:position];

    OSStatus err = MusicPlayerSetTime(self.musicPlayer, position);
    if (err) return NSLog(@"MusicPlayerSetTime() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);

    Float64 sequenceDuration = self.sequence.durationInSeconds;
    Float64 positionInTime;

    err = MusicSequenceGetSecondsForBeats(self.sequence.musicSequence, position, &positionInTime);
    if (err) return NSLog(@"MusicSequenceGetSecondsForBeats() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);

    err = MusicPlayerStart(self.musicPlayer);
    if (err) return NSLog(@"MusicPlayerStart() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
	[self.clickPlayer startPlaybackFromPosition:position];

    self.isPlaying = YES;
    NSDate *startTime = [NSDate date];
    self.lastPlaybackStartedTime = startTime;

	if (self.stopPlaybackAtEndOfSequence) {
		Float64 playbackDuration = (sequenceDuration - positionInTime) + self.tailDuration;
		if (playbackDuration <= 0) return;

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(playbackDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if ([startTime isEqualToDate:self.lastPlaybackStartedTime]) {
				if (!self.isLooping) {
					[self stopPlayback];
				}
			}
		});
	}
}

- (void)resumePlayback
{
    if (!self.lastStoppedAtTimeStampNumber) return [self startPlayback];

    MusicTimeStamp lastTimeStamp = [self.lastStoppedAtTimeStampNumber doubleValue];
    lastTimeStamp = [self.sequence equivalentTimeStampForLoopedTimeStamp:lastTimeStamp];

    [self startPlaybackFromPosition:lastTimeStamp];
}

- (void)stopPlayback
{
    if (!self.isPlaying) return;

    Boolean musicPlayerIsPlaying = TRUE;
    OSStatus err = MusicPlayerIsPlaying(self.musicPlayer, &musicPlayerIsPlaying);
    if (err) {
        NSLog(@"MusicPlayerIsPlaying() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    }

    self.lastStoppedAtTimeStampNumber = @(self.currentTimeStamp);

    if (musicPlayerIsPlaying) {
        err = MusicPlayerStop(self.musicPlayer);
        if (err) {
            NSLog(@"MusicPlayerStop() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
        }
    }

    [self unloopTracks];

	[self.clickPlayer stopPlayback];
	self.clickPlayer = nil;
    self.isPlaying = NO;
}

#pragma mark - Private

#pragma mark Looping

- (void)loopTracksWhenNeeded
{
    if (self.isLooping) {
        MusicTimeStamp length = self.sequence.length;
        MusicTrackLoopInfo loopInfo;
        loopInfo.numberOfLoops = 0;
        loopInfo.loopDuration = length;

        for (MIKMIDITrack *track in self.sequence.tracks) {
            [track setTemporaryLength:length andLoopInfo:loopInfo];
        }
    }
}

- (void)unloopTracks
{
    for (MIKMIDITrack *track in self.sequence.tracks) {
        [track restoreLengthAndLoopInfo];
    }
}

#pragma mark - Click Track

- (void)addClickTrackWhenNeededFromTimeStamp:(MusicTimeStamp)fromTimeStamp
{
	if (self.isClickPlayer) return;
	if (!self.isClickTrackEnabled) return;

	self.clickPlayer = [[MIKMIDIPlayer alloc] init];
	self.clickPlayer->_isClickPlayer = YES;
	MIKMIDISequence *clickSequence = [MIKMIDISequence sequence];
	[clickSequence.tempoTrack addEvents:self.sequence.tempoEvents];
	[clickSequence.tempoTrack addEvents:self.sequence.timeSignatureEvents];
	self.clickPlayer.sequence = clickSequence;
	MIKMIDITrack *clickTrack = [clickSequence addTrackWithError:NULL];

	OSStatus err = MusicTrackSetDestMIDIEndpoint(clickTrack.musicTrack, (MIDIEndpointRef)self.metronomeEndpoint.objectRef);
	if (err) {
		NSLog(@"MusicTrackGetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return;
	}
	MusicTimeStamp toTimeStamp = self.stopPlaybackAtEndOfSequence ? self.sequence.length : self.maxClickTrackTimeStamp;

	NSMutableSet *clickEvents = [NSMutableSet set];
	MIDINoteMessage tickMessage = self.metronome.tickMessage;
	MIDINoteMessage tockMessage = self.metronome.tockMessage;
	MusicTimeStamp increment = 1;
	for (MusicTimeStamp clickTimeStamp = floor(fromTimeStamp); clickTimeStamp <= toTimeStamp; clickTimeStamp += increment) {
		MIKMIDITimeSignature timeSignature = [clickSequence timeSignatureAtTimeStamp:clickTimeStamp];
		if (!timeSignature.numerator || !timeSignature.denominator) continue;

		NSInteger adjustedTimeStamp = (NSInteger)(clickTimeStamp * timeSignature.denominator / 4.0);
		BOOL isTick = !((adjustedTimeStamp + timeSignature.numerator) % (timeSignature.numerator));
		increment = 4.0 / timeSignature.denominator;

		MIDINoteMessage clickMessage = isTick ? tickMessage : tockMessage;
		[clickEvents addObject:[MIKMIDINoteEvent noteEventWithTimeStamp:clickTimeStamp message:clickMessage]];
	}

	[clickTrack addEvents:[clickEvents allObjects]];
}

#pragma mark - Properties

- (void)setLooping:(BOOL)looping
{
    if (looping != _looping) {
        _looping = looping;

        if (self.isPlaying) {
            [self stopPlayback];
            [self preparePlayback];
            [self resumePlayback];
        }
    }
}

- (void)setSequence:(MIKMIDISequence *)sequence
{
    if (sequence != _sequence) {
        if (self.isPlaying) [self stopPlayback];

        MusicSequence musicSequence = sequence.musicSequence;
        OSStatus err = MusicPlayerSetSequence(self.musicPlayer, musicSequence);
        if (err) return NSLog(@"MusicPlayerSetSequence() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);

        _sequence = sequence;
    }
}

- (MusicTimeStamp)currentTimeStamp
{
    MusicTimeStamp position = 0;
    OSStatus err = MusicPlayerGetTime(self.musicPlayer, &position);
    if (err) NSLog(@"MusicPlayerGetTime() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return position;
}

- (void)setCurrentTimeStamp:(MusicTimeStamp)currentTimeStamp
{
    OSStatus err = MusicPlayerSetTime(self.musicPlayer, currentTimeStamp);
    if (err) NSLog(@"MusicPlayerSetTime() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
}

- (MIKMIDIClientDestinationEndpoint *)metronomeEndpoint
{
	if (!_metronomeEndpoint) _metronomeEndpoint = [[MIKMIDIClientDestinationEndpoint alloc] initWithName:@"MIKMIDIClickTrackEndpoint" receivedMessagesHandler:NULL];
	return _metronomeEndpoint;
}

- (MIKMIDIMetronome *)metronome
{
	if (!_metronome) _metronome = [[MIKMIDIMetronome alloc] initWithClientDestinationEndpoint:self.metronomeEndpoint];
	return _metronome;
}

@end
