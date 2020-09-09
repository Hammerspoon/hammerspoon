//
//  MIKMIDITrack.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDISequence.h"
#import "MIKMIDITrack.h"
#import "MIKMIDIEvent.h"
#import "MIKMIDINoteEvent.h"
#import "MIKMIDITempoEvent.h"
#import "MIKMIDIEventIterator.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDIErrors.h"
#import "MIKMIDISequencer+MIKMIDIPrivate.h"


#if !__has_feature(objc_arc)
#error MIKMIDITrack.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDITrack.m in the Build Phases for this target
#endif

@interface MIKMIDITrack ()

@property (weak, nonatomic, nullable) MIKMIDISequence *sequence;
@property (nonatomic, strong) NSMutableSet *internalEvents;
@property (nonatomic, strong) NSArray *sortedEventsCache;

@property (nonatomic) MusicTimeStamp restoredLength;
@property (nonatomic) MusicTrackLoopInfo restoredLoopInfo;
@property (nonatomic) BOOL hasTemporaryLengthAndLoopInfo;

@end


@implementation MIKMIDITrack

#pragma mark - Lifecycle

- (instancetype)initWithSequence:(MIKMIDISequence *)sequence musicTrack:(MusicTrack)musicTrack
{
    if (self = [super init]) {
        MusicSequence musicTrackSequence;
        OSStatus err = MusicTrackGetSequence(musicTrack, &musicTrackSequence);
        if (err) NSLog(@"MusicTrackGetSequence() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);

        if (musicTrackSequence != sequence.musicSequence) {
            NSLog(@"ERROR: initWithSequence:musicTrack: requires the musicTrack's associated MusicSequence to be the same as sequence's musicSequence property.");
            return nil;
        }

		_internalEvents = [[NSMutableSet alloc] init];
        _musicTrack = musicTrack;
        _sequence = sequence;
		[self reloadAllEventsFromMusicTrack];
    }

    return self;
}

+ (instancetype)trackWithSequence:(MIKMIDISequence *)sequence musicTrack:(MusicTrack)musicTrack
{
    return [[self alloc] initWithSequence:sequence musicTrack:musicTrack];
}

- (instancetype)init
{
#ifdef DEBUG
    @throw [NSException exceptionWithName:NSGenericException reason:@"Invalid initializer." userInfo:nil];
#endif
    return nil;
}

#pragma mark - Sequencer Synchronization

- (void)dispatchSyncToSequencerProcessingQueueAsNeeded:(void (^)(void))block
{
	if (!block) return;

	MIKMIDISequencer *sequencer = self.sequence.sequencer;
	if (sequencer) {
		[sequencer dispatchSyncToProcessingQueueAsNeeded:block];
	} else {
		block();
	}
}

#pragma mark - Adding and Removing Events

#pragma mark Public

- (void)addEvent:(MIKMIDIEvent *)event
{
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		if (!event) return;
		if ([self.internalEvents containsObject:event]) return; // Don't allow duplicates

		NSError *error = nil;
		if (![self insertMIDIEventInMusicTrack:event error:&error]) {
			NSLog(@"Error adding %@ to %@: %@", event, self, error);
			[self reloadAllEventsFromMusicTrack];
			return;
		}

		[self addInternalEventsObject:event];
	}];
}

- (void)addEvents:(NSArray *)events
{
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		NSMutableSet *scratch = [NSMutableSet setWithArray:events];
		[scratch minusSet:self.internalEvents]; // Don't allow duplicates
		if (![scratch count]) return;

		NSError *error = nil;
		for (MIKMIDIEvent *event in scratch) {
			if (![self insertMIDIEventInMusicTrack:event error:&error]) {
				NSLog(@"Error adding %@ to %@: %@", event, self, error);
				[self reloadAllEventsFromMusicTrack];
				return;
			}
		}

		[self addInternalEvents:scratch];
	}];
}

- (void)removeEvent:(MIKMIDIEvent *)event
{
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		if (!event) return;
		if (![self.internalEvents containsObject:event]) return;

		NSError *error = nil;
		if (![self removeMIDIEventsFromMusicTrack:[NSSet setWithObject:event] error:&error]) {
			NSLog(@"Error removing %@ from %@: %@", event, self, error);
			[self reloadAllEventsFromMusicTrack];
			return;
		}

		[self removeInternalEventsObject:event];
	}];
}

- (void)removeEvents:(NSArray *)events
{
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		if (![events count]) return;
		NSMutableSet *scratch = [NSMutableSet setWithArray:events];
		[scratch intersectSet:self.internalEvents];

		NSError *error = nil;
		if (![self removeMIDIEventsFromMusicTrack:scratch error:&error]) {
			NSLog(@"Error removing %@ from %@: %@", events, self, error);
			[self reloadAllEventsFromMusicTrack];
			return;
		}

		[self removeInternalEvents:scratch];
	}];
}

- (void)removeAllEvents
{
	[self clearEventsFromStartingTimeStamp:0 toEndingTimeStamp:kMusicTimeStamp_EndOfTrack];
}

#pragma mark Private

- (BOOL)insertMIDIEventInMusicTrack:(MIKMIDIEvent *)event error:(NSError **)error
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	
    OSStatus err = noErr;
    MusicTrack track = self.musicTrack;
    MusicTimeStamp timeStamp = event.timeStamp;
    const void *data = [event.data bytes];

    switch (event.eventType) {
		case MIKMIDIEventTypeNULL:
			NSLog(@"Warning: %s attempted to insert NULL event.", __PRETTY_FUNCTION__);
            break;

		case MIKMIDIEventTypeExtendedNote:
            err = MusicTrackNewExtendedNoteEvent(track, timeStamp, data);
            if (err) NSLog(@"MusicTrackNewExtendedNoteEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            break;

#if !TARGET_OS_IPHONE // Unavailable altogether on iOS.
		case MIKMIDIEventTypeExtendedControl:
			NSLog(@"Events of type MIKMIDIEventTypeExtendedControl are unsupported because the underlying CoreMIDI API is deprecated.");
			break;
#endif
			
		case MIKMIDIEventTypeExtendedTempo:
            err = MusicTrackNewExtendedTempoEvent(track, timeStamp, ((ExtendedTempoEvent *)data)->bpm);
            if (err) NSLog(@"MusicTrackNewExtendedTempoEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            break;

		case MIKMIDIEventTypeUser:
            err = MusicTrackNewUserEvent(track, timeStamp, data);
            if (err) NSLog(@"MusicTrackNewUserEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            break;

		case MIKMIDIEventTypeMIDINoteMessage:
            err = MusicTrackNewMIDINoteEvent(track, timeStamp, data);
            if (err) NSLog(@"MusicTrackNewMIDINoteEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            break;

		case MIKMIDIEventTypeMIDIRawData:
            err = MusicTrackNewMIDIRawDataEvent(track, timeStamp, data);
            if (err) NSLog(@"MusicTrackNewMIDIRawDataEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            break;

		case MIKMIDIEventTypeParameter:
            err = MusicTrackNewParameterEvent(track, timeStamp, data);
            if (err) NSLog(@"MusicTrackNewParameterEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            break;

		case MIKMIDIEventTypeAUPreset:
            err = MusicTrackNewAUPresetEvent(track, timeStamp, data);
            if (err) NSLog(@"MusicTrackNewAUPresetEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            break;

		case MIKMIDIEventTypeMIDIChannelMessage:
		case MIKMIDIEventTypeMIDIPolyphonicKeyPressureMessage:
		case MIKMIDIEventTypeMIDIControlChangeMessage:
		case MIKMIDIEventTypeMIDIProgramChangeMessage:
		case MIKMIDIEventTypeMIDIChannelPressureMessage:
		case MIKMIDIEventTypeMIDIPitchBendChangeMessage:
			err = MusicTrackNewMIDIChannelEvent(track, timeStamp, data);
			if (err) NSLog(@"MusicTrackNewMIDIChannelEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
			break;
			
		case MIKMIDIEventTypeMeta:
		case MIKMIDIEventTypeMetaSequence:
		case MIKMIDIEventTypeMetaText:
		case MIKMIDIEventTypeMetaCopyright:
		case MIKMIDIEventTypeMetaTrackSequenceName:
		case MIKMIDIEventTypeMetaInstrumentName:
		case MIKMIDIEventTypeMetaLyricText:
		case MIKMIDIEventTypeMetaMarkerText:
		case MIKMIDIEventTypeMetaCuePoint:
		case MIKMIDIEventTypeMetaMIDIChannelPrefix:
		case MIKMIDIEventTypeMetaEndOfTrack:
		case MIKMIDIEventTypeMetaTempoSetting:
		case MIKMIDIEventTypeMetaSMPTEOffset:
		case MIKMIDIEventTypeMetaTimeSignature:
		case MIKMIDIEventTypeMetaKeySignature:
		case MIKMIDIEventTypeMetaSequenceSpecificEvent:
			err = MusicTrackNewMetaEvent(track, timeStamp, data);
			if (err) NSLog(@"MusicTrackNewMetaEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
			break;
		default:
			err = -1;
			NSLog(@"Warning: %s attempted to insert unknown event type %@.", __PRETTY_FUNCTION__, @(event.eventType));
			break;
}

	if (err != noErr) {
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return NO;
    }
    return YES;
}

- (BOOL)removeMIDIEventsFromMusicTrack:(NSSet *)events error:(NSError **)error
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	if (![events count]) return YES;
	
	// MusicTrackClear() doesn't reliably clear events that fall on its boundaries,
	// so we iterate the track and delete that way instead
	BOOL success = NO;
	MIKMIDIEventIterator *iterator = [MIKMIDIEventIterator iteratorForTrack:self];
	while (iterator.hasCurrentEvent) {
		MIKMIDIEvent *currentEvent = iterator.currentEvent;
		if ([events containsObject:currentEvent]) {
			if (![iterator deleteCurrentEventWithError:error]) return NO;
			success = YES;
			continue; // Move to next event is done by delete.
    }

		[iterator moveToNextEvent];
    }

	*error = [NSError MIKMIDIErrorWithCode:MIKMIDITrackEventNotFoundErrorCode userInfo:nil];
	return success;
}

#pragma mark - Getting Events

#pragma mark Public

// All public event getters pass through this method
- (NSArray *)eventsOfClass:(Class)eventClass fromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp
{
	NSMutableArray *result = [NSMutableArray array];
	for (MIKMIDIEvent *event in self.events) {
		if (event.timeStamp < startTimeStamp) { continue; }
		if (event.timeStamp > endTimeStamp) { break; }
		if (eventClass && ![event isKindOfClass:eventClass]) { continue; }
		[result addObject:event];
	}
	return [result copy];
}

- (NSArray *)eventsFromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp
{
	return [self eventsOfClass:[MIKMIDIEvent class] fromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp];
}

- (NSArray *)notesFromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp
{
	return [self eventsOfClass:[MIKMIDINoteEvent class] fromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp];
}

#pragma mark Private

- (void)reloadAllEventsFromMusicTrack
{
	MIKMIDIEventIterator *iterator = [MIKMIDIEventIterator iteratorForTrack:self];
	NSMutableSet *allEvents = [NSMutableSet set];
	while (iterator.hasCurrentEvent) {
		MIKMIDIEvent *event = iterator.currentEvent;
		[allEvents addObject:event];
		[iterator moveToNextEvent];
	}

	[self willChangeValueForKey:@"internalEvents"];
	[self.internalEvents intersectSet:allEvents];
	[self.internalEvents unionSet:allEvents];
	[self didChangeValueForKey:@"internalEvents"];
	
	self.sortedEventsCache = nil;
}

#pragma mark - Editing Events (Public)

- (BOOL)moveEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp byAmount:(MusicTimeStamp)timestampOffset
{
	__block BOOL success = NO;

	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		success = [self private_moveEventsFromStartingTimeStamp:startTimeStamp toEndingTimeStamp:endTimeStamp byAmount:timestampOffset];
	}];

	return success;
}

- (BOOL)private_moveEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp byAmount:(MusicTimeStamp)timestampOffset
{
	// MusicTrackMoveEvents() fails in common edge cases, so iterate the track and move that way instead

	if (timestampOffset == 0) return YES; // Nothing needs to be done
	MusicTimeStamp length = self.length;
	if (!length || (startTimeStamp > length) || ![self.internalEvents count]) return YES;
	if (endTimeStamp > length) endTimeStamp = length;

	NSMutableSet *eventsToMove = [NSMutableSet setWithArray:[self eventsFromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp]];
	NSSet *eventsBeforeMoving = [eventsToMove copy];
	NSMutableSet *eventsAfterMoving = [NSMutableSet set];

	MIKMIDIEventIterator *iterator = [MIKMIDIEventIterator iteratorForTrack:self];
	while (iterator.hasCurrentEvent && [eventsToMove count] > 0) {
		MIKMIDIEvent *currentEvent = iterator.currentEvent;
		if (![eventsToMove containsObject:currentEvent]) {
			[iterator moveToNextEvent];
			continue;
		}

		MusicTimeStamp timestamp = currentEvent.timeStamp;
		if (![iterator moveCurrentEventTo:timestamp+timestampOffset error:NULL]) {
			[self reloadAllEventsFromMusicTrack];
			return NO;
		}
		MIKMutableMIDIEvent *movedEvent = [currentEvent mutableCopy];
		movedEvent.timeStamp += timestampOffset;
		[eventsAfterMoving addObject:[movedEvent copy]];
		[eventsToMove removeObject:currentEvent];
		[iterator seek:timestamp]; // Move back to previous position
	}

	[self removeInternalEvents:eventsBeforeMoving];
	[self addInternalEvents:eventsAfterMoving];

	return YES;
}

- (BOOL)clearEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp
{
	__block BOOL success = NO;

	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		success = [self private_clearEventsFromStartingTimeStamp:startTimeStamp toEndingTimeStamp:endTimeStamp];
	}];

	return success;
}

- (BOOL)private_clearEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp
{
	NSSet *events = [NSSet setWithArray:[self eventsFromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp]];
	BOOL success = [self removeMIDIEventsFromMusicTrack:events error:NULL];
	[self reloadAllEventsFromMusicTrack];
	return success;
}

- (BOOL)cutEventsFromStartingTimeStamp:(MusicTimeStamp)startTimeStamp toEndingTimeStamp:(MusicTimeStamp)endTimeStamp
{
	__block BOOL success = NO;

	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		MusicTimeStamp length = self.length;
		if (!length || (startTimeStamp > length) || ![self.internalEvents count]) { success = YES; return; }

		MusicTimeStamp actualEndTimeStamp = endTimeStamp;
		if (actualEndTimeStamp > length) actualEndTimeStamp = length;

		if (![self private_clearEventsFromStartingTimeStamp:startTimeStamp toEndingTimeStamp:actualEndTimeStamp]) return;
		MusicTimeStamp cutAmount = actualEndTimeStamp - startTimeStamp;
		success = [self private_moveEventsFromStartingTimeStamp:actualEndTimeStamp toEndingTimeStamp:kMusicTimeStamp_EndOfTrack byAmount:-cutAmount];
	}];

	return success;
}

- (BOOL)copyEventsFromMIDITrack:(MIKMIDITrack *)origTrack fromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp andInsertAtTimeStamp:(MusicTimeStamp)destTimeStamp
{
	__block BOOL success = NO;

	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		// Move existing events to make room for new events
		if (![self private_moveEventsFromStartingTimeStamp:destTimeStamp
										 toEndingTimeStamp:kMusicTimeStamp_EndOfTrack
												  byAmount:(endTimeStamp - startTimeStamp)]) return;

		success = [self private_mergeEventsFromMIDITrack:origTrack fromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp atTimeStamp:destTimeStamp];
	}];

	return success;
}

- (BOOL)mergeEventsFromMIDITrack:(MIKMIDITrack *)origTrack fromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp atTimeStamp:(MusicTimeStamp)destTimeStamp
{
	__block BOOL success = NO;

	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		success = [self private_mergeEventsFromMIDITrack:origTrack fromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp atTimeStamp:destTimeStamp];
	}];

	return success;
}

- (BOOL)private_mergeEventsFromMIDITrack:(MIKMIDITrack *)origTrack fromTimeStamp:(MusicTimeStamp)startTimeStamp toTimeStamp:(MusicTimeStamp)endTimeStamp atTimeStamp:(MusicTimeStamp)destTimeStamp
{
	NSArray *sourceEvents = [origTrack eventsFromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp];
	if (![sourceEvents count]) return YES;

	MusicTimeStamp firstSourceTimeStamp = [[sourceEvents firstObject] timeStamp];
		
	NSMutableSet *destinationEvents = [NSMutableSet set];
	for (MIKMIDIEvent *event in sourceEvents) {
		MIKMutableMIDIEvent *mutableEvent = [event mutableCopy];
		mutableEvent.timeStamp = destTimeStamp + (event.timeStamp - firstSourceTimeStamp);
		if (![self insertMIDIEventInMusicTrack:mutableEvent error:NULL]) {
			[self reloadAllEventsFromMusicTrack];
			return NO;
		}
		[destinationEvents addObject:mutableEvent];
	}

	[self addInternalEvents:destinationEvents];
	return YES;
}

#pragma mark - Temporary Length and Loop Info

- (void)setTemporaryLength:(MusicTimeStamp)length andLoopInfo:(MusicTrackLoopInfo)loopInfo
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	self.restoredLength = self.length;
	self.restoredLoopInfo = self.loopInfo;
	self.length = length;
	self.loopInfo = loopInfo;
	self.hasTemporaryLengthAndLoopInfo = YES;
#pragma clang diagnostic pop
}

- (void)restoreLengthAndLoopInfo
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	if (!self.hasTemporaryLengthAndLoopInfo) return;

	self.hasTemporaryLengthAndLoopInfo = NO;
	self.length = self.restoredLength;
	self.loopInfo = self.restoredLoopInfo;
#pragma clang diagnostic pop
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingEvents
{
	return [NSSet setWithObjects:@"sortedEventsCache", nil];
}

- (NSArray *)events
{
	__block NSArray *events;

	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		if (!self.sortedEventsCache) {
			NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:YES];
			self->_sortedEventsCache = [self.internalEvents sortedArrayUsingDescriptors:@[sortDescriptor]];
		}
		events = self.sortedEventsCache;
	}];

	return events ?: @[];
}

- (void)setEvents:(NSArray *)events
{
	[self clearEventsFromStartingTimeStamp:0 toEndingTimeStamp:self.length];
	[self dispatchSyncToSequencerProcessingQueueAsNeeded:^{
		for (MIKMIDIEvent *event in events) {
			NSError *error = nil;
			if (![self insertMIDIEventInMusicTrack:event error:&error]) {
				NSLog(@"Error adding %@ to %@: %@", event, self, error);
				[self reloadAllEventsFromMusicTrack];
				return;
			}
		}

		self.internalEvents = [NSMutableSet setWithArray:events];
	}];
}

- (void)setInternalEvents:(NSMutableSet *)internalEvents
{
	if (internalEvents != _internalEvents) {
		_internalEvents = internalEvents;
		self.sortedEventsCache = nil;
	}
}

- (void)addInternalEventsObject:(MIKMIDIEvent *)event
{
	[self.internalEvents addObject:[event copy]];
	self.sortedEventsCache = nil;
}

- (void)addInternalEvents:(NSSet *)events
{
	for (MIKMIDIEvent *event in events) {
		[self addInternalEventsObject:[event copy]];
	}
}

- (void)removeInternalEventsObject:(MIKMIDIEvent *)event
{
	[self.internalEvents removeObject:event];
	self.sortedEventsCache = nil;
}

- (void)removeInternalEvents:(NSSet *)events
{
	[self.internalEvents minusSet:events];
	self.sortedEventsCache = nil;
}

+ (NSSet *)keyPathsForValuesAffectingNotes
{
	return [NSSet setWithObjects:@"sortedEventsCache", nil];
}

- (NSArray *)notes
{
	NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *b) {
		return [(MIKMIDIEvent *)obj eventType] == MIKMIDIEventTypeMIDINoteMessage;
	}];
	return [self.events filteredArrayUsingPredicate:predicate];
}

- (NSInteger)trackNumber
{
    __strong MIKMIDISequence *sequence = self.sequence;
	if (!sequence) return -1;
	UInt32 trackNumber = 0;
	OSStatus err = MusicSequenceGetTrackIndex(sequence.musicSequence, self.musicTrack, &trackNumber);
	if (err) {
		NSLog(@"MusicSequenceGetTrackIndex() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return -1;
	}
	return (NSInteger)trackNumber;
}

@synthesize offset = _offset;

- (MusicTimeStamp)offset
{
	if (_offset != 0) return _offset;
	
	if (self.musicTrack) {
		MusicTimeStamp offset = 0;
		UInt32 offsetLength = sizeof(offset);
		OSStatus err = MusicTrackGetProperty(self.musicTrack, kSequenceTrackProperty_OffsetTime, &offset, &offsetLength);
		if (err) NSLog(@"MusicTrackGetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return offset;
	} else {
		return 0;
	}
}

- (void)setOffset:(MusicTimeStamp)offset
{
	_offset = offset;
	
	if (self.musicTrack) {
		OSStatus err = MusicTrackSetProperty(self.musicTrack, kSequenceTrackProperty_OffsetTime, &offset, sizeof(offset));
		if (err) NSLog(@"MusicTrackSetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
	}
}

@synthesize muted = _muted;

- (BOOL)isMuted
{
	if (_muted) return YES;
	
	if (self.musicTrack) {
		Boolean isMuted = FALSE;
		UInt32 isMutedLength = sizeof(isMuted);
		OSStatus err = MusicTrackGetProperty(self.musicTrack, kSequenceTrackProperty_MuteStatus, &isMuted, &isMutedLength);
		if (err) NSLog(@"MusicTrackGetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return isMuted ? YES : NO;
	} else {
		return NO;
	}
}

- (void)setMuted:(BOOL)muted
{
	_muted = muted;
	
	if (self.musicTrack) {
		Boolean mutedBoolean = muted ? TRUE : FALSE;
		OSStatus err = MusicTrackSetProperty(self.musicTrack, kSequenceTrackProperty_MuteStatus, &mutedBoolean, sizeof(mutedBoolean));
		if (err) NSLog(@"MusicTrackSetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
	}
}

@synthesize solo = _solo;

- (BOOL)isSolo
{
	if (_solo) return YES;
	
	if (self.musicTrack) {
		Boolean isSolo = FALSE;
		UInt32 isSoloLength = sizeof(isSolo);
		OSStatus err = MusicTrackGetProperty(self.musicTrack, kSequenceTrackProperty_SoloStatus, &isSolo, &isSoloLength);
		if (err) NSLog(@"MusicTrackGetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		return isSolo ? YES : NO;
	} else {
		return NO;
	}
}

- (void)setSolo:(BOOL)solo
{
	_solo = solo;
	
	if (self.musicTrack) {
		Boolean soloBoolean = solo ? TRUE : FALSE;
		OSStatus err = MusicTrackSetProperty(self.musicTrack, kSequenceTrackProperty_SoloStatus, &soloBoolean, sizeof(soloBoolean));
		if (err) NSLog(@"MusicTrackSetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
	}
}

+ (NSSet *)keyPathsForValuesAffectingLength
{
	return [NSSet setWithObjects:@"sortedEventsCache", nil];
}

- (MusicTimeStamp)length
{
	if (_length == -1) {
		MusicTimeStamp lastStamp = 0;

		for (MIKMIDIEvent *event in self.events) {
			MusicTimeStamp endStamp = [event respondsToSelector:@selector(endTimeStamp)] ? [(MIKMIDINoteEvent *)event endTimeStamp] : event.timeStamp;
			if (endStamp > lastStamp) lastStamp = endStamp;
		}

		_length = lastStamp;
	}

	return _length;
}

- (void)setSortedEventsCache:(NSArray *)sortedEventsCache
{
	_sortedEventsCache = sortedEventsCache;
	_length = -1;
}

- (SInt16)timeResolution
{
    SInt16 resolution = 0;
    UInt32 resolutionLength = sizeof(resolution);
    OSStatus err = MusicTrackGetProperty(self.musicTrack, kSequenceTrackProperty_TimeResolution, &resolution, &resolutionLength);
    if (err) NSLog(@"MusicTrackGetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return resolution;
}

#pragma mark - Deprecated

+ (NSSet *)keyPathsForValuesAffectingDoesLoop
{
	return [NSSet setWithObjects:@"loopDuration", nil];
}

- (BOOL)doesLoop
{
	return self.loopDuration > 0;
}

+ (NSSet *)keyPathsForValuesAffectingNumberOfLoops
{
	return [NSSet setWithObjects:@"loopInfo", nil];
}

- (SInt32)numberOfLoops
{
	return self.loopInfo.numberOfLoops;
}

- (void)setNumberOfLoops:(SInt32)numberOfLoops
{
	MusicTrackLoopInfo loopInfo = self.loopInfo;

	if (loopInfo.numberOfLoops != numberOfLoops) {
		loopInfo.numberOfLoops = numberOfLoops;
		self.loopInfo = loopInfo;
	}
}

+ (NSSet *)keyPathsForValuesAffectingLoopDuration
{
	return [NSSet setWithObjects:@"loopInfo", nil];
}

- (MusicTimeStamp)loopDuration
{
	return self.loopInfo.loopDuration;
}

- (void)setLoopDuration:(MusicTimeStamp)loopDuration
{
	MusicTrackLoopInfo loopInfo = self.loopInfo;

	if (loopInfo.loopDuration != loopDuration) {
		loopInfo.loopDuration = loopDuration;
		self.loopInfo = loopInfo;
	}
}

- (MusicTrackLoopInfo)loopInfo
{
	MusicTrackLoopInfo info;
	UInt32 infoSize = sizeof(info);
	OSStatus err = MusicTrackGetProperty(self.musicTrack, kSequenceTrackProperty_LoopInfo, &info, &infoSize);
	if (err) NSLog(@"MusicTrackGetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
	return info;
}

- (void)setLoopInfo:(MusicTrackLoopInfo)loopInfo
{
	OSStatus err = MusicTrackSetProperty(self.musicTrack, kSequenceTrackProperty_LoopInfo, &loopInfo, sizeof(loopInfo));
	if (err) NSLog(@"MusicTrackSetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
}

- (BOOL)getTrackNumber:(UInt32 *)trackNumber
{
	static BOOL deprectionMsgShown = NO;
	if (!deprectionMsgShown) {
		NSLog(@"WARNING: %s has been deprecated. Please use -trackNumber instead. This message will only be logged once", __PRETTY_FUNCTION__);
		deprectionMsgShown = YES;
	}
	NSInteger result = self.trackNumber;
	*trackNumber = (UInt32)result;
	return (result >= 0);
}

@synthesize destinationEndpoint = _destinationEndpoint;

- (MIKMIDIDestinationEndpoint *)destinationEndpoint
{
	NSLog(@"%s is deprecated. You should update your code to avoid calling this method. Use MIKMIDISequencer's API instead.", __PRETTY_FUNCTION__);
	return _destinationEndpoint;
}

- (void)setDestinationEndpoint:(MIKMIDIDestinationEndpoint *)destinationEndpoint
{
	NSLog(@"%s is deprecated. You should update your code to avoid calling this method. Use MIKMIDISequencer's API instead.", __PRETTY_FUNCTION__);

    if (destinationEndpoint != _destinationEndpoint) {
        OSStatus err = MusicTrackSetDestMIDIEndpoint(self.musicTrack, (MIDIEndpointRef)destinationEndpoint.objectRef);
        if (err) NSLog(@"MusicTrackGetProperty() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
        _destinationEndpoint = destinationEndpoint;
    }
}

- (BOOL)insertMIDIEvent:(MIKMIDIEvent *)event
{
	static BOOL deprectionMsgShown = NO;
	if (!deprectionMsgShown) {
		NSLog(@"WARNING: %s has been deprecated. Please use -addEvent: instead. This message will only be logged once.", __PRETTY_FUNCTION__);
		deprectionMsgShown = YES;
	}
	
	[self addEvent:event];
	return YES;
}

- (BOOL)insertMIDIEvents:(NSSet *)events
{
	static BOOL deprectionMsgShown = NO;
	if (!deprectionMsgShown) {
		NSLog(@"WARNING: %s has been deprecated. Please use -addEvent: instead. This message will only be logged once.", __PRETTY_FUNCTION__);
		deprectionMsgShown = YES;
	}
	
	for (MIKMIDIEvent *event in events) {
		[self addEvent:event];
	}
	return YES;
}

- (BOOL)removeMIDIEvents:(NSSet *)events
{
	static BOOL deprectionMsgShown = NO;
	if (!deprectionMsgShown) {
		NSLog(@"WARNING: %s has been deprecated. Please use -removeEvent: instead. This message will only be logged once.", __PRETTY_FUNCTION__);
		deprectionMsgShown = YES;
	}
	
	for (MIKMIDIEvent *event in events) {
		[self removeEvent:event];
	}
	return YES;
}

- (BOOL)clearAllEvents
{
	static BOOL deprectionMsgShown = NO;
	if (!deprectionMsgShown) {
		NSLog(@"WARNING: %s has been deprecated. Please use -removeAllEvents instead. This message will only be logged once.", __PRETTY_FUNCTION__);
		deprectionMsgShown = YES;
	}
	
	[self removeAllEvents];
	return YES;
}

@end
