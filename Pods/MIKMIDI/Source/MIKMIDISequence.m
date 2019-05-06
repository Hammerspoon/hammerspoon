//
//  MIKMIDISequence.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDISequence.h"
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDITrack.h"
#import "MIKMIDITrack_Protected.h"
#import "MIKMIDITempoEvent.h"
#import "MIKMIDIMetaTimeSignatureEvent.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDISequence+MIKMIDIPrivate.h"
#import "MIKMIDISequencer+MIKMIDIPrivate.h"
#import "MIKMIDIErrors.h"

#if !__has_feature(objc_arc)
#error MIKMIDISequence.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDISequence.m in the Build Phases for this target
#endif

void * MIKMIDISequenceKVOContext = &MIKMIDISequenceKVOContext;

const MusicTimeStamp MIKMIDISequenceLongestTrackLength = -1;

@interface MIKMIDISequence ()

@property (nonatomic) MusicSequence musicSequence;
@property (nonatomic, strong) MIKMIDITrack *tempoTrack;
@property (nonatomic, strong) NSMutableArray *internalTracks;
@property (nonatomic) MusicTimeStamp lengthDefinedByTracks;

@end


@implementation MIKMIDISequence

#pragma mark - Lifecycle

+ (instancetype)sequence
{
	return [[self alloc] init];
}

- (instancetype)init
{
	MusicSequence sequence;
	OSStatus err = NewMusicSequence(&sequence);
	if (err) {
		NSLog(@"NewMusicSequence() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return nil;
	}
	
	return [self initWithMusicSequence:sequence error:NULL];
}

+ (instancetype)sequenceWithFileAtURL:(NSURL *)fileURL error:(NSError **)error;
{
	return [[self alloc] initWithFileAtURL:fileURL convertMIDIChannelsToTracks:NO error:error];
}

+ (instancetype)sequenceWithFileAtURL:(NSURL *)fileURL convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error
{
	return [[self alloc] initWithFileAtURL:fileURL convertMIDIChannelsToTracks:convertMIDIChannelsToTracks error:error];
}

- (instancetype)initWithFileAtURL:(NSURL *)fileURL error:(NSError **)error;
{
	return [self initWithFileAtURL:fileURL convertMIDIChannelsToTracks:NO error:error];
}

- (instancetype)initWithFileAtURL:(NSURL *)fileURL convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error
{
	NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:error];
	if (!data) return nil;
	return [self initWithData:data convertMIDIChannelsToTracks:convertMIDIChannelsToTracks error:error];
}

+ (instancetype)sequenceWithData:(NSData *)data error:(NSError **)error
{
	return [[self alloc] initWithData:data convertMIDIChannelsToTracks:NO error:error];
}

+ (instancetype)sequenceWithData:(NSData *)data convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error
{
	return [[self alloc] initWithData:data convertMIDIChannelsToTracks:convertMIDIChannelsToTracks error:error];
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)error
{
	return [self initWithData:data convertMIDIChannelsToTracks:NO error:error];
}

- (instancetype)initWithData:(NSData *)data convertMIDIChannelsToTracks:(BOOL)convertMIDIChannelsToTracks error:(NSError **)error
{
	error = error ?: &(NSError *__autoreleasing){ nil };
	
	MusicSequence sequence;
	OSStatus err = NewMusicSequence(&sequence);
	if (err) {
		NSLog(@"NewMusicSequence() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return nil;
	}
	
	MusicSequenceLoadFlags flags = convertMIDIChannelsToTracks ? kMusicSequenceLoadSMF_ChannelsToTracks : 0;
	err = MusicSequenceFileLoadData(sequence, (__bridge CFDataRef)data, kMusicSequenceFile_MIDIType, flags);
	if (err) {
		NSLog(@"MusicSequenceFileLoadData() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return nil;
	}
	
	return [self initWithMusicSequence:sequence error:error];
}

+ (instancetype)sequenceWithMusicSequence:(MusicSequence)musicSequence error:(NSError **)error
{
	return [[self alloc] initWithMusicSequence:musicSequence error:error];
}

- (instancetype)initWithMusicSequence:(MusicSequence)musicSequence error:(NSError **)error
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	
	if (self = [super init]) {
		OSStatus err = MusicSequenceSetUserCallback(musicSequence, MIKSequenceCallback, (__bridge void *)self);
		if (err) {
			NSLog(@"MusicSequenceSetUserCallback() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
			*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
			return nil;
		}
		self.musicSequence = musicSequence;
		
		MusicTrack tempoTrack;
		err = MusicSequenceGetTempoTrack(musicSequence, &tempoTrack);
		if (err) {
			NSLog(@"MusicSequenceGetTempoTrack() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
			*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
			return nil;
		}
		self.tempoTrack = [MIKMIDITrack trackWithSequence:self musicTrack:tempoTrack];
		
		UInt32 numTracks = 0;
		err = MusicSequenceGetTrackCount(musicSequence, &numTracks);
		if (err) {
			NSLog(@"MusicSequenceGetTrackCount() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
			*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
			return nil;
		}
		NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:numTracks];
		
		for (UInt32 i = 0; i < numTracks; i++) {
			MusicTrack musicTrack;
			err = MusicSequenceGetIndTrack(musicSequence, i, &musicTrack);
			if (err){
				NSLog(@"MusicSequenceGetIndTrack() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
				*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
				return nil;
			}
			[tracks addObject:[MIKMIDITrack trackWithSequence:self musicTrack:musicTrack]];
		}
		self.internalTracks = tracks;
		self.length = MIKMIDISequenceLongestTrackLength;
	}
	
	return self;
}

- (void)dealloc
{
	NSArray *tracks = self.internalTracks;
	self.internalTracks = nil; // Unregister for KVO
	[self setCallBackBlock:^(MIKMIDITrack *t, MusicTimeStamp ts, const MusicEventUserData *ud, MusicTimeStamp ts2, MusicTimeStamp ts3) {}];
	
	for (MIKMIDITrack *track in tracks) {
		OSStatus err = MusicSequenceDisposeTrack(_musicSequence, track.musicTrack);
		if (err) NSLog(@"MusicSequenceDisposeTrack() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
	}
	
	OSStatus err = DisposeMusicSequence(_musicSequence);
	if (err) NSLog(@"DisposeMusicSequence() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
}

#pragma mark - Sequencer Synchronization

- (void)dispatchSyncToSequencerProcessingQueueAsNeeded:(void (^)(void))block
{
	if (!block) return;
	
	MIKMIDISequencer *sequencer = self.sequencer;
	if (sequencer) {
		[sequencer dispatchSyncToProcessingQueueAsNeeded:block];
	} else {
		block();
	}
}

#pragma mark - Adding and Removing Tracks

- (MIKMIDITrack *)addTrackWithError:(NSError * __autoreleasing *)error
{
	__block MIKMIDITrack *track = nil;
	error = error ?: &(NSError *__autoreleasing){ nil };
	
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		MusicTrack musicTrack;
		OSStatus err = MusicSequenceNewTrack(self.musicSequence, &musicTrack);
		if (err) {
			NSLog(@"MusicSequenceNewTrack() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
			NSError *underlyingError = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
			NSDictionary *userInfo = @{NSUnderlyingErrorKey : underlyingError};
			*error = [NSError MIKMIDIErrorWithCode:MIKMIDISequenceAddTrackFailedErrorCode userInfo:userInfo];
			return;
		};
		
		track = [MIKMIDITrack trackWithSequence:self musicTrack:musicTrack];
		[self insertObject:track inInternalTracksAtIndex:[self.internalTracks count]];
	}];
	
	return track;
}

- (MIKMIDITrack *)addTrack
{
	return [self addTrackWithError:NULL];
}

- (BOOL)removeTrack:(MIKMIDITrack *)track
{
	if (!track) return NO;
	
	__block BOOL success = NO;
	
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		OSStatus err = MusicSequenceDisposeTrack(self.musicSequence, track.musicTrack);
		if (err) return NSLog(@"MusicSequenceDisposeTrack() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		
		NSInteger index = [self.internalTracks indexOfObject:track];
		if (index != NSNotFound) [self removeObjectFromInternalTracksAtIndex:index];
		success = YES;
	}];
	
	return success;
}

#pragma mark - File Saving

- (BOOL)writeToURL:(NSURL *)fileURL error:(NSError *__autoreleasing *)error
{
	return [self.dataValue writeToURL:fileURL options:NSDataWritingAtomic error:error];
}

#pragma mark - Callback

static void MIKSequenceCallback(void *inClientData, MusicSequence inSequence, MusicTrack inTrack, MusicTimeStamp inEventTime, const MusicEventUserData *inEventData, MusicTimeStamp inStartSliceBeat, MusicTimeStamp inEndSliceBeat)
{
	MIKMIDISequence *self = (__bridge MIKMIDISequence *)inClientData;
	if (!self.callBackBlock) return;
	
	UInt32 trackIndex;
	OSStatus err = MusicSequenceGetTrackIndex(inSequence, inTrack, &trackIndex);
	if (err) {
		NSLog(@"MusicSequenceGetTrackIndex() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return;
	}
	
	MIKMIDITrack *track = self.tracks[trackIndex];
	if (track && self.callBackBlock) {
		self.callBackBlock(track, inEventTime, inEventData, inStartSliceBeat, inEndSliceBeat);
	}
}

#pragma mark - Looping

- (MusicTimeStamp)equivalentTimeStampForLoopedTimeStamp:(MusicTimeStamp)loopedTimeStamp
{
	MusicTimeStamp length = self.length;
	
	if (loopedTimeStamp > length) {
		NSInteger numTimesLooped = (NSInteger)(loopedTimeStamp / length);
		loopedTimeStamp -= (length * numTimesLooped);
	}
	
	return loopedTimeStamp;
}

#pragma mark - Tempo

- (NSArray *)tempoEvents
{
	return [self.tempoTrack eventsOfClass:[MIKMIDITempoEvent class] fromTimeStamp:0 toTimeStamp:kMusicTimeStamp_EndOfTrack];
}

- (BOOL)setOverallTempo:(Float64)bpm
{
	NSArray *timeSignatureEvents = [self timeSignatureEvents];
	[self.tempoTrack removeAllEvents];
	if ([self.tempoTrack.events count]) return NO;
	[self.tempoTrack addEvents:timeSignatureEvents];
	return [self setTempo:bpm atTimeStamp:0];
}

- (BOOL)setTempo:(Float64)bpm atTimeStamp:(MusicTimeStamp)timeStamp
{
	[self.tempoTrack addEvent:[MIKMIDITempoEvent tempoEventWithTimeStamp:timeStamp tempo:bpm]];
	return YES;
}

- (Float64)tempoAtTimeStamp:(MusicTimeStamp)timeStamp
{
	__block Float64 tempo = 0;
	
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		NSArray *events = [self.tempoTrack eventsOfClass:[MIKMIDITempoEvent class] fromTimeStamp:0 toTimeStamp:timeStamp];
		tempo = [[events lastObject] bpm];
	}];
	
	return tempo;
}

#pragma mark - Time Signature

- (NSArray *)timeSignatureEvents
{
	return [self.tempoTrack eventsOfClass:[MIKMIDIMetaTimeSignatureEvent class] fromTimeStamp:0 toTimeStamp:kMusicTimeStamp_EndOfTrack];
}

- (BOOL)setOverallTimeSignature:(MIKMIDITimeSignature)signature
{
	NSArray *tempoEvents = [self tempoEvents];
	[self.tempoTrack removeAllEvents];
	if ([self.tempoTrack.events count]) return NO;
	[self.tempoTrack addEvents:tempoEvents];
	return [self setTimeSignature:signature atTimeStamp:0];
}

- (BOOL)setTimeSignature:(MIKMIDITimeSignature)signature atTimeStamp:(MusicTimeStamp)timeStamp
{
	MIKMutableMIDIMetaTimeSignatureEvent *event = [[MIKMutableMIDIMetaTimeSignatureEvent alloc] init];
	event.timeStamp = timeStamp;
	event.numerator = signature.numerator;
	event.denominator = signature.denominator;
	event.metronomePulse = (UInt8)self.tempoTrack.timeResolution;
	event.thirtySecondsPerQuarterNote = 8;
	[self.tempoTrack addEvent:event];
	return YES;
}

- (MIKMIDITimeSignature)timeSignatureAtTimeStamp:(MusicTimeStamp)timeStamp
{
	MIKMIDITimeSignature result = {4, 4};
	NSArray *events = [self.tempoTrack eventsOfClass:[MIKMIDIMetaTimeSignatureEvent class] fromTimeStamp:0 toTimeStamp:timeStamp];
	MIKMIDIMetaTimeSignatureEvent *event = [events lastObject];
	if (event) {
		result.numerator = event.numerator;
		result.denominator = event.denominator;
	}
	return result;
}

#pragma mark - Description

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ tempo track: %@ tracks: %@", [super description], self.tempoTrack, self.tracks];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context != MIKMIDISequenceKVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	
	if ([self.internalTracks containsObject:object] &&
		([keyPath isEqualToString:@"length"] || [keyPath isEqualToString:@"offset"])) {
		[self updateLengthDefinedByTracks];
	}
}

- (void)updateLengthDefinedByTracks
{
	MusicTimeStamp length = 0;
	for (MIKMIDITrack *track in self.tracks) {
		MusicTimeStamp trackLength = track.length + track.offset;
		if (trackLength > length) length = trackLength;
	}
	
	self.lengthDefinedByTracks = length;
}

#pragma mark - Properties

- (void)setInternalTracks:(NSMutableArray *)internalTracks
{
	if (internalTracks != _internalTracks) {
		for (MIKMIDITrack *track in _internalTracks) {
			[track removeObserver:self forKeyPath:@"length"];
			[track removeObserver:self forKeyPath:@"offset"];
		}
		
		_internalTracks = internalTracks;
		
		for (MIKMIDITrack *track in _internalTracks) {
			[track addObserver:self forKeyPath:@"length" options:NSKeyValueObservingOptionInitial context:MIKMIDISequenceKVOContext];
			[track addObserver:self forKeyPath:@"offset" options:NSKeyValueObservingOptionInitial context:MIKMIDISequenceKVOContext];
		}
	}
}

- (void)insertObject:(MIKMIDITrack *)track inInternalTracksAtIndex:(NSUInteger)index
{
	if (!track) return;
	
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"tracks"];
	[self.internalTracks insertObject:track atIndex:index];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"tracks"];
	[track addObserver:self forKeyPath:@"length" options:NSKeyValueObservingOptionInitial context:MIKMIDISequenceKVOContext];
	[track addObserver:self forKeyPath:@"offset" options:NSKeyValueObservingOptionInitial context:MIKMIDISequenceKVOContext];
}

- (void)removeObjectFromInternalTracksAtIndex:(NSUInteger)index
{
	if (index >= [self.internalTracks count]) return;
	MIKMIDITrack *track = self.internalTracks[index];
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"tracks"];
	[self.internalTracks removeObjectAtIndex:index];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"tracks"];
	[track removeObserver:self forKeyPath:@"length"];
	[track removeObserver:self forKeyPath:@"offset"];
	[self updateLengthDefinedByTracks];
}

+ (BOOL)automaticallyNotifiesObserversOfTracks { return NO; }

- (NSArray *)tracks
{
	__block NSArray *tracks;
	
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		tracks = self.internalTracks;
	}];
	
	return tracks ?: @[];
}

+ (NSSet *)keyPathsForValuesAffectingLength
{
	return [NSSet setWithObjects:@"lengthDefinedByTracks", nil];
}

@synthesize length = _length;
- (MusicTimeStamp)length
{
	__block MusicTimeStamp length = 0;
	
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		length = (self->_length == MIKMIDISequenceLongestTrackLength) ? self.lengthDefinedByTracks : self->_length;
	}];
	
	return length;
}

- (void)setLength:(MusicTimeStamp)length
{
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		self->_length = length;
	}];
}

+ (NSSet *)keyPathsForValuesAffectingDurationInSeconds
{
	return [NSSet setWithObjects:@"length", nil];
}

- (Float64)durationInSeconds
{
	Float64 duration = 0;
	OSStatus err = MusicSequenceGetSecondsForBeats(self.musicSequence, self.length, &duration);
	if (err) NSLog(@"MusicSequenceGetSecondsForBeats() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
	return duration;
}

- (NSData *)dataValue
{
	CFDataRef data;
	OSStatus err = MusicSequenceFileCreateData(self.musicSequence, kMusicSequenceFile_MIDIType, 0, 0, &data);
	if (err) {
		NSLog(@"MusicSequenceFileCreateData() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return nil;
	}
	
	return (__bridge_transfer NSData *)data;
}

#pragma mark - Deprecated

+ (instancetype)sequenceWithData:(NSData *)data
{
	NSLog(@"%s is deprecated."
		  "You should update your code to avoid calling this method."
		  "Use +sequenceWithData:error: instead.", __PRETTY_FUNCTION__);
	return [self sequenceWithData:data error:NULL];
}

- (instancetype)initWithData:(NSData *)data
{
	NSLog(@"%s is deprecated."
		  "You should update your code to avoid calling this method."
		  "Use -initWithData:error: instead.", __PRETTY_FUNCTION__);
	return [self initWithData:data error:NULL];
}

- (void)setDestinationEndpoint:(MIKMIDIDestinationEndpoint *)destinationEndpoint
{
	NSLog(@"%s is deprecated. You should update your code to avoid calling this method. Use MIKMIDISequencer's API instead.", __PRETTY_FUNCTION__);
	for (MIKMIDITrack *track in self.tracks) {
		track.destinationEndpoint = destinationEndpoint;
	}
}

- (BOOL)getTempo:(Float64 *)bpm atTimeStamp:(MusicTimeStamp)timeStamp
{
	static BOOL deprectionMsgShown = NO;
	if (!deprectionMsgShown) {
		NSLog(@"WARNING: %s has been deprecated. Please use -timeSignatureAtTimeStamp: instead. This message will only be logged once", __PRETTY_FUNCTION__);
		deprectionMsgShown = YES;
	}
	
	if (!bpm) return NO;
	Float64 result = [self tempoAtTimeStamp:timeStamp];
	if (result == 0.0) return NO;
	*bpm = result;
	return YES;
}

- (BOOL)getTimeSignature:(MIKMIDITimeSignature *)signature atTimeStamp:(MusicTimeStamp)timeStamp
{
	static BOOL deprectionMsgShown = NO;
	if (!deprectionMsgShown) {
		NSLog(@"WARNING: %s has been deprecated. Please use -timeSignatureAtTimeStamp: instead. This message will only be logged once", __PRETTY_FUNCTION__);
		deprectionMsgShown = YES;
	}
	
	if (!signature) return NO;
	MIKMIDITimeSignature result = [self timeSignatureAtTimeStamp:timeStamp];
	if (result.numerator == 0) return NO;
	signature->numerator = result.numerator;
	signature->denominator = result.denominator;
	return YES;
}

@end
