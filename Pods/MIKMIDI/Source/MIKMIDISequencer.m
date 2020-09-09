//
//  MIKMIDISequencer.m
//  MIKMIDI
//
//  Created by Chris Flesner on 11/26/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDISequencer.h"
#import <mach/mach_time.h>
#import "MIKMIDISequence.h"
#import "MIKMIDITrack.h"
#import "MIKMIDIClock.h"
#import "MIKMIDITempoEvent.h"
#import "MIKMIDINoteEvent.h"
#import "MIKMIDIChannelEvent.h"
#import "MIKMIDINoteOnCommand.h"
#import "MIKMIDINoteOffCommand.h"
#import "MIKMIDIDeviceManager.h"
#import "MIKMIDIMetronome.h"
#import "MIKMIDIMetaTimeSignatureEvent.h"
#import "MIKMIDIUtilities.h"
#import "MIKMIDISynthesizer.h"
#import "MIKMIDISequencer+MIKMIDIPrivate.h"
#import "MIKMIDISequence+MIKMIDIPrivate.h"
#import "MIKMIDICommandScheduler.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDIControlChangeCommand.h"
#import "MIKMIDIControlChangeEvent.h"


#if !__has_feature(objc_arc)
#error MIKMIDISequencer.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDISequencer.m in the Build Phases for this target
#endif

#define kDefaultTempo	120

NSString * const MIKMIDISequencerWillLoopNotification = @"MIKMIDISequencerWillLoopNotification";
const MusicTimeStamp MIKMIDISequencerEndOfSequenceLoopEndTimeStamp = -1;


#pragma mark -

@interface MIKMIDIEventWithDestination : NSObject
@property (nonatomic, strong) MIKMIDIEvent *event;
@property (nonatomic, strong) id<MIKMIDICommandScheduler> destination;
@property (nonatomic, readonly) BOOL representsNoteOff;
+ (instancetype)eventWithDestination:(id<MIKMIDICommandScheduler>)destination event:(MIKMIDIEvent *)event;
+ (instancetype)eventWithDestination:(id<MIKMIDICommandScheduler>)destination event:(MIKMIDIEvent *)event representsNoteOff:(BOOL)representsNoteOff;
@end


@interface MIKMIDICommandWithDestination : NSObject
@property (nonatomic, strong) MIKMIDICommand *command;
@property (nonatomic, strong) id<MIKMIDICommandScheduler> destination;
+ (instancetype)commandWithDestination:(id<MIKMIDICommandScheduler>)destination command:(MIKMIDICommand *)command;
@end


@interface MIKMIDIPendingNoteOffsForTimeStamp : NSObject
@property (nonatomic, strong) NSMutableArray *noteEventsWithEndTimeStamp;
@property (nonatomic) MusicTimeStamp endTimeStamp;
+ (instancetype)pendingNoteOffWithEndTimeStamp:(MusicTimeStamp)endTimeStamp;
@end


#pragma mark -

@interface MIKMIDISequencer ()
{
    void *_processingQueueKey;
    void *_processingQueueContext;
}

@property (readonly, nonatomic) MIKMIDIClock *clock;

@property (nonatomic, getter=isPlaying) BOOL playing;
@property (nonatomic, getter=isRecording) BOOL recording;
@property (nonatomic, getter=isLooping) BOOL looping;

@property (nonatomic) MIDITimeStamp latestScheduledMIDITimeStamp;

@property (nonatomic, strong) NSMutableDictionary *pendingNoteOffs;

@property (nonatomic, strong) NSMutableDictionary *pendingRecordedNoteEvents;

@property (nonatomic) MusicTimeStamp startingTimeStamp;
@property (nonatomic) MusicTimeStamp initialStartingTimeStamp;

@property (nonatomic, strong) NSMapTable *tracksToDestinationsMap;
@property (nonatomic, strong) NSMapTable *tracksToDefaultSynthsMap;

@property (nonatomic) BOOL needsCurrentTempoUpdate;

@property (readonly, nonatomic) MusicTimeStamp sequenceLength;

@property (nonatomic) dispatch_queue_t processingQueue;
@property (nonatomic) dispatch_source_t processingTimer;

@end


@implementation MIKMIDISequencer

#pragma mark - Lifecycle

- (instancetype)initWithSequence:(MIKMIDISequence *)sequence
{
    if (self = [super init]) {
        self.sequence = sequence;
        _clock = [MIKMIDIClock clock];
        _syncedClock = [_clock syncedClock];
        _loopEndTimeStamp = MIKMIDISequencerEndOfSequenceLoopEndTimeStamp;
        _preRoll = 4;
        _clickTrackStatus = MIKMIDISequencerClickTrackStatusEnabledInRecord;
        _tracksToDestinationsMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
        _tracksToDefaultSynthsMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
        _createSynthsIfNeeded = YES;
        _processingQueueKey = &_processingQueueKey;
        _processingQueueContext = &_processingQueueContext;
        _maximumLookAheadInterval = 0.1;
    }
    return self;
}

+ (instancetype)sequencerWithSequence:(MIKMIDISequence *)sequence
{
    return [[self alloc] initWithSequence:sequence];
}

- (instancetype)init
{
    return [self initWithSequence:[MIKMIDISequence sequence]];
}

+ (instancetype)sequencer
{
    return [[self alloc] init];
}

- (void)dealloc
{
    [_sequence removeObserver:self forKeyPath:@"tracks"];
    self.processingTimer = NULL;
}

#pragma mark - Playback

- (void)startPlayback
{
    [self startPlaybackAtTimeStamp:0];
}

- (void)startPlaybackAtTimeStamp:(MusicTimeStamp)timeStamp
{
    [self startPlaybackAtTimeStamp:timeStamp adjustForPreRollWhenRecording:YES];
}

- (void)startPlaybackAtTimeStamp:(MusicTimeStamp)timeStamp adjustForPreRollWhenRecording:(BOOL)adjustForPreRoll
{
    MIDITimeStamp midiTimeStamp = MIKMIDIGetCurrentTimeStamp() + MIKMIDIClockMIDITimeStampsPerTimeInterval(0.001);
    [self startPlaybackAtTimeStamp:timeStamp MIDITimeStamp:midiTimeStamp];
}

- (void)startPlaybackAtTimeStamp:(MusicTimeStamp)timeStamp MIDITimeStamp:(MIDITimeStamp)midiTimeStamp
{
    [self startPlaybackAtTimeStamp:timeStamp MIDITimeStamp:midiTimeStamp adjustForPreRollWhenRecording:YES];
}

- (void)startPlaybackAtTimeStamp:(MusicTimeStamp)timeStamp MIDITimeStamp:(MIDITimeStamp)midiTimeStamp adjustForPreRollWhenRecording:(BOOL)adjustForPreRoll
{
    if (self.isPlaying) [self stop];
    if (adjustForPreRoll && self.isRecording) timeStamp -= self.preRoll;

    NSString *queueLabel = [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingFormat:@".%@.%p", [self class], self];
    dispatch_queue_attr_t attr = DISPATCH_QUEUE_SERIAL;

#if defined (__MAC_10_10) || defined (__IPHONE_8_0)
    if (@available(macOS 10.10, iOS 8, *)) {
        if (&dispatch_queue_attr_make_with_qos_class != NULL) {
            attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
        }
    }
#endif

    dispatch_queue_t queue = dispatch_queue_create(queueLabel.UTF8String, attr);
    dispatch_queue_set_specific(queue, &_processingQueueKey, &_processingQueueContext, NULL);
    self.processingQueue = queue;

    dispatch_sync(queue, ^{
        self.startingTimeStamp = timeStamp;
        self.initialStartingTimeStamp = timeStamp;

        Float64 startingTempo = [self.sequence tempoAtTimeStamp:timeStamp];
        if (!startingTempo) startingTempo = kDefaultTempo;
        [self updateClockWithMusicTimeStamp:timeStamp tempo:startingTempo atMIDITimeStamp:midiTimeStamp];
    });

    self.playing = YES;

    dispatch_sync(queue, ^{
        self.pendingNoteOffs = [NSMutableDictionary dictionary];
        self.latestScheduledMIDITimeStamp = midiTimeStamp;
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processingQueue);
        if (!timer) return NSLog(@"Unable to create processing timer for %@.", [self class]);
        self.processingTimer = timer;

        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC, 0.05 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{
            [self processSequenceStartingFromMIDITimeStamp:self.latestScheduledMIDITimeStamp];
        });

        dispatch_resume(timer);
    });
}

- (void)resumePlayback
{
    [self startPlaybackAtTimeStamp:self.currentTimeStamp];
}

- (void)stop
{
    [self stopWithDispatchToProcessingQueue:YES];
}

- (void)stopAllPlayingNotesForCommandScheduler:(id<MIKMIDICommandScheduler>)scheduler
{
    [self dispatchSyncToProcessingQueueAsNeeded:^{
        NSMutableArray *commandsToSendNow = [NSMutableArray array];
        MIDITimeStamp offTimeStamp = MIKMIDIGetCurrentTimeStamp() + MIKMIDIClockMIDITimeStampsPerTimeInterval(self.maximumLookAheadInterval);

        for (MIKMIDIPendingNoteOffsForTimeStamp *pendingNoteOffsForTimeStamp in self.pendingNoteOffs.allValues) {
            NSMutableArray *noteEvents = pendingNoteOffsForTimeStamp.noteEventsWithEndTimeStamp;
            NSUInteger count = noteEvents.count;
            NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
            for (NSUInteger i = 0; i < count; i++) {
                MIKMIDIEventWithDestination *event = noteEvents[i];
                if (event.destination == scheduler) {
                    [indexesToRemove addIndex:i];

                    MIKMIDINoteEvent *noteEvent = (MIKMIDINoteEvent *)event.event;
                    MIKMIDINoteOffCommand *command = [MIKMIDINoteOffCommand noteOffCommandWithNote:noteEvent.note velocity:0 channel:noteEvent.channel midiTimeStamp:offTimeStamp];
                    [commandsToSendNow addObject:command];
                }
            }

            [noteEvents removeObjectsAtIndexes:indexesToRemove];
        }

        if (commandsToSendNow.count) [self scheduleCommands:commandsToSendNow withCommandScheduler:scheduler];
    }];
}

- (void)stopWithDispatchToProcessingQueue:(BOOL)dispatchToProcessingQueue
{
    MIDITimeStamp stopTimeStamp = MIKMIDIGetCurrentTimeStamp();
    if (!self.isPlaying) return;

    void (^stopPlayback)(void) = ^{
        self.processingTimer = NULL;

        MIKMIDIClock *clock = self.clock;
        [self recordAllPendingNoteEventsWithOffTimeStamp:[clock musicTimeStampForMIDITimeStamp:stopTimeStamp]];
        MusicTimeStamp allPendingNotesOffTimeStamp = MAX(self.latestScheduledMIDITimeStamp + 1, MIKMIDIGetCurrentTimeStamp() + MIKMIDIClockMIDITimeStampsPerTimeInterval(0.001));
        [self sendAllPendingNoteOffsWithMIDITimeStamp:allPendingNotesOffTimeStamp];
        self.pendingRecordedNoteEvents = nil;
        self.looping = NO;

        MusicTimeStamp stopMusicTimeStamp = [clock musicTimeStampForMIDITimeStamp:stopTimeStamp];
        self->_currentTimeStamp = (stopMusicTimeStamp <= self.sequenceLength) ? stopMusicTimeStamp : self.sequenceLength;

        [clock unsyncMusicTimeStampsAndTemposFromMIDITimeStamps];
    };

    dispatchToProcessingQueue ? dispatch_sync(self.processingQueue, stopPlayback) : stopPlayback();

    self.processingQueue = NULL;
    self.playing = NO;
    self.recording = NO;
}

- (void)processSequenceStartingFromMIDITimeStamp:(MIDITimeStamp)fromMIDITimeStamp
{
    MIDITimeStamp toMIDITimeStamp = MIKMIDIGetCurrentTimeStamp() + MIKMIDIClockMIDITimeStampsPerTimeInterval(self.maximumLookAheadInterval);
    if (toMIDITimeStamp < fromMIDITimeStamp) return;
    MIKMIDIClock *clock = self.clock;

    MIKMIDISequence *sequence = self.sequence;
    MusicTimeStamp loopStartTimeStamp = self.loopStartTimeStamp;
    MusicTimeStamp loopEndTimeStamp = self.effectiveLoopEndTimeStamp;
    MusicTimeStamp fromMusicTimeStamp = [clock musicTimeStampForMIDITimeStamp:fromMIDITimeStamp];
    MusicTimeStamp calculatedToMusicTimeStamp = [clock musicTimeStampForMIDITimeStamp:toMIDITimeStamp];
    BOOL isLooping = (self.shouldLoop && calculatedToMusicTimeStamp > loopStartTimeStamp && loopEndTimeStamp > loopStartTimeStamp);
    if (isLooping != self.isLooping) self.looping = isLooping;
    MusicTimeStamp maxToMusicTimeStamp = self.isRecording ? DBL_MAX : self.sequenceLength; // If recording, don't limit max timestamp (Issue #45)
    maxToMusicTimeStamp = isLooping ? loopEndTimeStamp : maxToMusicTimeStamp;
    MusicTimeStamp toMusicTimeStamp = MIN(calculatedToMusicTimeStamp, maxToMusicTimeStamp);
    MIDITimeStamp actualToMIDITimeStamp = [clock midiTimeStampForMusicTimeStamp:toMusicTimeStamp];

    // Get relevant tempo events
    NSMutableDictionary *allEventsByTimeStamp = [NSMutableDictionary dictionary];
    NSMutableDictionary *tempoEventsByTimeStamp = [NSMutableDictionary dictionary];
    Float64 overrideTempo = self.tempo;

    if (!overrideTempo) {
        NSArray *sequenceTempoEvents = [sequence.tempoTrack eventsOfClass:[MIKMIDITempoEvent class] fromTimeStamp:MAX(fromMusicTimeStamp, 0) toTimeStamp:toMusicTimeStamp];
        for (MIKMIDITempoEvent *tempoEvent in sequenceTempoEvents) {
            NSNumber *timeStampKey = @(tempoEvent.timeStamp);
            allEventsByTimeStamp[timeStampKey] = [NSMutableArray arrayWithObject:tempoEvent];
            tempoEventsByTimeStamp[timeStampKey] = tempoEvent;
        }
    }

    if (self.needsCurrentTempoUpdate) {
        if (!tempoEventsByTimeStamp.count) {
            if (!overrideTempo) overrideTempo = [sequence tempoAtTimeStamp:fromMusicTimeStamp];
            if (!overrideTempo) overrideTempo = kDefaultTempo;

            MIKMIDITempoEvent *tempoEvent = [MIKMIDITempoEvent tempoEventWithTimeStamp:fromMusicTimeStamp tempo:overrideTempo];
            NSNumber *timeStampKey = @(fromMusicTimeStamp);
            allEventsByTimeStamp[timeStampKey] = [NSMutableArray arrayWithObject:tempoEvent];
            tempoEventsByTimeStamp[timeStampKey] = tempoEvent;
        }
        self.needsCurrentTempoUpdate = NO;
    }

    // Get pending note off events
    NSMutableDictionary *pendingNoteOffs = self.pendingNoteOffs;
    for (NSNumber *timeStampKey in [pendingNoteOffs copy]) {
        MusicTimeStamp pendingNoteOffsMusicTimeStamp = timeStampKey.doubleValue;
        if (pendingNoteOffsMusicTimeStamp < fromMusicTimeStamp) continue;
        if (pendingNoteOffsMusicTimeStamp > toMusicTimeStamp) continue;
        if (isLooping && (pendingNoteOffsMusicTimeStamp == loopEndTimeStamp)) continue;	// These pending note offs will be handled right before we loop

        NSMutableArray *eventsAtTimeStamp = allEventsByTimeStamp[timeStampKey] ? allEventsByTimeStamp[timeStampKey] : [NSMutableArray array];
        [eventsAtTimeStamp addObject:pendingNoteOffs[timeStampKey]];
        allEventsByTimeStamp[timeStampKey] = eventsAtTimeStamp;
        [pendingNoteOffs removeObjectForKey:timeStampKey];
    }

    // Get other events
    NSMutableArray *nonMutedTracks = [[NSMutableArray alloc] init];
    NSMutableArray *soloTracks = [[NSMutableArray alloc] init];
    for (MIKMIDITrack *track in sequence.tracks) {
        if (track.isMuted) continue;

        [nonMutedTracks addObject:track];
        if (track.solo) { [soloTracks addObject:track]; }
    }

    // Never play muted tracks. If any non-muted tracks are soloed, only play those. Matches MusicPlayer behavior
    NSArray *tracksToPlay = soloTracks.count != 0 ? soloTracks : nonMutedTracks;

    for (MIKMIDITrack *track in tracksToPlay) {
        MusicTimeStamp startTimeStamp = MAX(fromMusicTimeStamp - track.offset, 0);
        MusicTimeStamp endTimeStamp = toMusicTimeStamp - track.offset;
        NSArray *events = [track eventsFromTimeStamp:startTimeStamp toTimeStamp:endTimeStamp];
        if (track.offset != 0) {
            // Shift events by offset
            NSMutableArray *shiftedEvents = [NSMutableArray array];
            for (MIKMIDIEvent *event in events) {
                MIKMutableMIDIEvent *shiftedEvent = [event mutableCopy];
                shiftedEvent.timeStamp += track.offset;
                [shiftedEvents addObject:shiftedEvent];
            }
            events = shiftedEvents;
        }

        id<MIKMIDICommandScheduler> destination = events.count ? [self commandSchedulerForTrack:track] : nil;	// only get the destination if there's events so we don't create a destination endpoint if not needed
        for (MIKMIDIEvent *event in events) {
            if ([event isKindOfClass:[MIKMIDINoteEvent class]] && [(MIKMIDINoteEvent *)event duration] <= 0) continue;
            NSNumber *timeStampKey = @(event.timeStamp);
            NSMutableArray *eventsAtTimeStamp = allEventsByTimeStamp[timeStampKey] ? allEventsByTimeStamp[timeStampKey] : [NSMutableArray array];
            [eventsAtTimeStamp addObject:[MIKMIDIEventWithDestination eventWithDestination:destination event:event]];
            allEventsByTimeStamp[timeStampKey] = eventsAtTimeStamp;
        }
    }

    // Get click track events
    for (MIKMIDIEventWithDestination *destinationEvent in [self clickTrackEventsFromTimeStamp:fromMusicTimeStamp toTimeStamp:toMusicTimeStamp]) {
        NSNumber *timeStampKey = @(destinationEvent.event.timeStamp);
        NSMutableArray *eventsAtTimesStamp = allEventsByTimeStamp[timeStampKey] ? allEventsByTimeStamp[timeStampKey] : [NSMutableArray array];
        [eventsAtTimesStamp addObject:destinationEvent];
        allEventsByTimeStamp[timeStampKey] = eventsAtTimesStamp;
    }

    // Schedule events
    for (NSNumber *timeStampKey in [allEventsByTimeStamp.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        MusicTimeStamp musicTimeStamp = timeStampKey.doubleValue;
        if (isLooping && (musicTimeStamp < loopStartTimeStamp || musicTimeStamp >= loopEndTimeStamp)) continue;
        MIDITimeStamp midiTimeStamp = [clock midiTimeStampForMusicTimeStamp:musicTimeStamp];
        if (midiTimeStamp < MIKMIDIGetCurrentTimeStamp() && midiTimeStamp > fromMIDITimeStamp) continue;	// prevents events that were just recorded from being scheduled

        MIKMIDITempoEvent *tempoEventAtTimeStamp = tempoEventsByTimeStamp[timeStampKey];
        if (tempoEventAtTimeStamp) [self updateClockWithMusicTimeStamp:musicTimeStamp tempo:tempoEventAtTimeStamp.bpm atMIDITimeStamp:midiTimeStamp];

        NSArray *events = allEventsByTimeStamp[timeStampKey];
        for (id eventObject in events) {
            if ([eventObject isKindOfClass:[MIKMIDIEventWithDestination class]]) {
                [self scheduleEventWithDestination:eventObject];
            } else if ([eventObject isKindOfClass:[MIKMIDIPendingNoteOffsForTimeStamp class]]) {
                for (MIKMIDIEventWithDestination *noteOffEvent in [eventObject noteEventsWithEndTimeStamp]) {
                    [self scheduleEventWithDestination:noteOffEvent];
                }
            }
        }
    }

    self.latestScheduledMIDITimeStamp = actualToMIDITimeStamp;

    // Handle looping or stopping at the end of the sequence
    if (isLooping) {
        if (calculatedToMusicTimeStamp > toMusicTimeStamp) {
            [self recordAllPendingNoteEventsWithOffTimeStamp:loopEndTimeStamp];
            Float64 tempo = [sequence tempoAtTimeStamp:loopStartTimeStamp];
            if (!tempo) tempo = kDefaultTempo;
            MusicTimeStamp loopLength = loopEndTimeStamp - loopStartTimeStamp;

            MIDITimeStamp loopStartMIDITimeStamp = [clock midiTimeStampForMusicTimeStamp:loopStartTimeStamp + loopLength];
            [self sendAllPendingNoteOffsWithMIDITimeStamp:loopStartMIDITimeStamp];
            [self updateClockWithMusicTimeStamp:loopStartTimeStamp tempo:tempo atMIDITimeStamp:loopStartMIDITimeStamp];

            self.startingTimeStamp = loopStartTimeStamp;
            [[NSNotificationCenter defaultCenter] postNotificationName:MIKMIDISequencerWillLoopNotification object:self userInfo:nil];
            [self processSequenceStartingFromMIDITimeStamp:loopStartMIDITimeStamp];
        }
    } else if (!self.isRecording) { // Don't stop automatically during recording
        MIDITimeStamp systemTimeStamp = MIKMIDIGetCurrentTimeStamp();
        if ((systemTimeStamp > actualToMIDITimeStamp) && ([clock musicTimeStampForMIDITimeStamp:systemTimeStamp] >= self.sequenceLength)) {
            [self stopWithDispatchToProcessingQueue:NO];
        }
    }
}

- (void)scheduleEventWithDestination:(MIKMIDIEventWithDestination *)destinationEvent
{
    MIKMIDIEvent *event = destinationEvent.event;
    id<MIKMIDICommandScheduler> destination = destinationEvent.destination;
    MIKMIDIClock *clock = self.clock;
    MIKMIDICommand *command;

    if (event.eventType == MIKMIDIEventTypeMIDINoteMessage) {
        if (destinationEvent.representsNoteOff) {
            command = [MIKMIDICommand noteOffCommandFromNoteEvent:(MIKMIDINoteEvent *)event clock:clock];
        } else {
            MIKMIDINoteEvent *noteEvent = (MIKMIDINoteEvent *)event;
            command = [MIKMIDICommand noteOnCommandFromNoteEvent:noteEvent clock:clock];

            // Add note off to pending note offs
            MusicTimeStamp endTimeStamp = noteEvent.endTimeStamp;
            NSMutableDictionary *pendingNoteOffs = self.pendingNoteOffs;
            MIKMIDIPendingNoteOffsForTimeStamp *pendingNoteOffsForEndTimeStamp = pendingNoteOffs[@(endTimeStamp)];
            if (!pendingNoteOffsForEndTimeStamp) {
                pendingNoteOffsForEndTimeStamp = [MIKMIDIPendingNoteOffsForTimeStamp pendingNoteOffWithEndTimeStamp:endTimeStamp];
                pendingNoteOffs[@(endTimeStamp)] = pendingNoteOffsForEndTimeStamp;
            }
            [pendingNoteOffsForEndTimeStamp.noteEventsWithEndTimeStamp addObject:[MIKMIDIEventWithDestination eventWithDestination:destination event:event representsNoteOff:YES]];
        }
    } else if ([event isKindOfClass:[MIKMIDIChannelEvent class]]) {
        command = [MIKMIDICommand commandFromChannelEvent:(MIKMIDIChannelEvent *)event clock:clock];
    }

    if (command) [self scheduleCommands:@[command] withCommandScheduler:destination];
}

- (void)sendAllPendingNoteOffsWithMIDITimeStamp:(MIDITimeStamp)offTimeStamp
{
    NSMutableDictionary *noteOffs = self.pendingNoteOffs;
    if (!noteOffs.count) return;

    NSMapTable *noteOffDestinationsToCommands = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
    MIKMIDIClock *clock = self.clock;

    for (NSNumber *musicTimeStampNumber in noteOffs) {
        MIKMIDIPendingNoteOffsForTimeStamp *pendingNoteOffs = noteOffs[musicTimeStampNumber];
        for (MIKMIDIEventWithDestination *noteOffEventWithDestination in pendingNoteOffs.noteEventsWithEndTimeStamp) {
            MIKMIDINoteEvent *event = (MIKMIDINoteEvent *)noteOffEventWithDestination.event;
            id<MIKMIDICommandScheduler> destination = noteOffEventWithDestination.destination;
            NSMutableArray *noteOffCommandsForDestination = [noteOffDestinationsToCommands objectForKey:destination] ? [noteOffDestinationsToCommands objectForKey:destination] : [NSMutableArray array];

            MIKMutableMIDICommand *noteOffCommand = [[MIKMIDICommand noteOffCommandFromNoteEvent:event clock:clock] mutableCopy];
            noteOffCommand.midiTimestamp = offTimeStamp;
            [noteOffCommandsForDestination addObject:noteOffCommand];
            [noteOffDestinationsToCommands setObject:noteOffCommandsForDestination forKey:destination];
        }
    }

    for (id<MIKMIDICommandScheduler> scheduler in [[noteOffDestinationsToCommands keyEnumerator] allObjects]) {
        [self scheduleCommands:[noteOffDestinationsToCommands objectForKey:scheduler] withCommandScheduler:scheduler];
    }

    [noteOffs removeAllObjects];
}

- (void)updateClockWithMusicTimeStamp:(MusicTimeStamp)musicTimeStamp tempo:(Float64)tempo atMIDITimeStamp:(MIDITimeStamp)midiTimeStamp
{
    // Override tempo if neccessary
    Float64 tempoOverride = self.tempo;
    if (tempoOverride) tempo = tempoOverride;
    [self.clock syncMusicTimeStamp:musicTimeStamp withMIDITimeStamp:midiTimeStamp tempo:tempo];
}

- (void)scheduleCommands:(NSArray *)commands withCommandScheduler:(id<MIKMIDICommandScheduler>)scheduler
{
    [scheduler scheduleMIDICommands:[self modifiedMIDICommandsFromCommandsToBeScheduled:commands forCommandScheduler:scheduler]];
}

- (NSArray *)modifiedMIDICommandsFromCommandsToBeScheduled:(NSArray *)commandsToBeScheduled forCommandScheduler:(id<MIKMIDICommandScheduler>)scheduler { return commandsToBeScheduled; }

#pragma mark - Recording

- (void)startRecording
{
    [self prepareForRecordingWithPreRoll:YES];
    [self startPlayback];
}

- (void)startRecordingAtTimeStamp:(MusicTimeStamp)timeStamp
{
    [self prepareForRecordingWithPreRoll:YES];
    [self startPlaybackAtTimeStamp:timeStamp];
}

- (void)startRecordingAtTimeStamp:(MusicTimeStamp)timeStamp MIDITimeStamp:(MIDITimeStamp)midiTimeStamp
{
    [self prepareForRecordingWithPreRoll:YES];
    [self startPlaybackAtTimeStamp:timeStamp MIDITimeStamp:midiTimeStamp];
}

- (void)resumeRecording
{
    [self prepareForRecordingWithPreRoll:YES];
    [self resumePlayback];
}

- (void)prepareForRecordingWithPreRoll:(BOOL)includePreRoll
{
    self.pendingRecordedNoteEvents = [NSMutableDictionary dictionary];
    self.recording = YES;
}

- (void)recordMIDICommand:(MIKMIDICommand *)command
{
    if (!self.isRecording) return;

    MIDITimeStamp midiTimeStamp = command.midiTimestamp;
    MusicTimeStamp musicTimeStamp = [self.clock musicTimeStampForMIDITimeStamp:midiTimeStamp];

    if (musicTimeStamp < 0) { return; } // Command is in pre-roll

    MIKMIDIEvent *event;
    if ([command isKindOfClass:[MIKMIDINoteOnCommand class]]) {				// note On
        MIKMIDINoteOnCommand *noteOnCommand = (MIKMIDINoteOnCommand *)command;
        if (noteOnCommand.velocity) {
            MIDINoteMessage message = { .channel = noteOnCommand.channel, .note = noteOnCommand.note, .velocity = noteOnCommand.velocity, 0, 0 };
            MIKMutableMIDINoteEvent *noteEvent = [MIKMutableMIDINoteEvent noteEventWithTimeStamp:musicTimeStamp message:message];
            NSNumber *noteNumber = @(noteOnCommand.note);
            NSMutableSet *noteEventsAtNote = self.pendingRecordedNoteEvents[noteNumber];
            if (!noteEventsAtNote) {
                noteEventsAtNote = [NSMutableSet setWithCapacity:1];
                self.pendingRecordedNoteEvents[noteNumber] = noteEventsAtNote;
            }
            [noteEventsAtNote addObject:noteEvent];
        } else {	// Velocity is 0, treat as a note Off per MIDI spec
            event = [self pendingNoteEventWithNoteNumber:@(noteOnCommand.note) channel:noteOnCommand.channel releaseVelocity:0 offTimeStamp:musicTimeStamp];
        }
    } else if ([command isKindOfClass:[MIKMIDINoteOffCommand class]]) {		// note Off
        MIKMIDINoteOffCommand *noteOffCommand = (MIKMIDINoteOffCommand *)command;
        event = [self pendingNoteEventWithNoteNumber:@(noteOffCommand.note) channel:noteOffCommand.channel releaseVelocity:noteOffCommand.velocity offTimeStamp:musicTimeStamp];
    } else if ([command isKindOfClass:[MIKMIDIControlChangeCommand class]]) { // cc command
        MIKMIDIControlChangeCommand* ccCmd = (MIKMIDIControlChangeCommand*)command;
        MIKMutableMIDIControlChangeEvent* ccEvent = [[MIKMutableMIDIControlChangeEvent alloc] init];
        ccEvent.controllerNumber = ccCmd.controllerNumber;
        ccEvent.controllerValue = ccCmd.controllerValue;
        ccEvent.channel = ccCmd.channel;
        ccEvent.timeStamp = musicTimeStamp;
        event = ccEvent;
    }

    if (event) [self.recordEnabledTracks makeObjectsPerformSelector:@selector(addEvent:) withObject:event];
}

- (void)recordAllPendingNoteEventsWithOffTimeStamp:(MusicTimeStamp)offTimeStamp
{
    NSMutableSet *events = [NSMutableSet set];

    NSMutableDictionary *pendingRecordedNoteEvents = self.pendingRecordedNoteEvents;
    for (NSNumber *noteNumber in pendingRecordedNoteEvents) {
        for (MIKMutableMIDINoteEvent *event in pendingRecordedNoteEvents[noteNumber]) {
            event.releaseVelocity = 0;
            event.duration = offTimeStamp - event.timeStamp;
            [events addObject:event];
        }
    }
    self.pendingRecordedNoteEvents = [NSMutableDictionary dictionary];

    if ([events count]) {
        for (MIKMIDITrack *track in self.recordEnabledTracks) {
            [track addEvents:[events allObjects]];
        }
    }
}

- (MIKMIDINoteEvent	*)pendingNoteEventWithNoteNumber:(NSNumber *)noteNumber channel:(UInt8)channel releaseVelocity:(UInt8)releaseVelocity offTimeStamp:(MusicTimeStamp)offTimeStamp
{
    NSMutableSet *pendingRecordedNoteEventsAtNote = self.pendingRecordedNoteEvents[noteNumber];
    for (MIKMutableMIDINoteEvent *noteEvent in [pendingRecordedNoteEventsAtNote copy]) {
        if (channel == noteEvent.channel) {
            noteEvent.releaseVelocity = releaseVelocity;
            noteEvent.duration = offTimeStamp - noteEvent.timeStamp;

            if (pendingRecordedNoteEventsAtNote.count > 1) {
                [pendingRecordedNoteEventsAtNote removeObject:noteEvent];
            } else {
                [self.pendingRecordedNoteEvents removeObjectForKey:noteNumber];
            }

            return noteEvent;
        }
    }
    return nil;
}

#pragma mark - Configuration

- (void)setCommandScheduler:(id<MIKMIDICommandScheduler>)commandScheduler forTrack:(MIKMIDITrack *)track
{
    if (!commandScheduler) {
        [self.tracksToDestinationsMap removeObjectForKey:track];
        return;
    }
    [self.tracksToDestinationsMap setObject:commandScheduler forKey:track];
    [self.tracksToDefaultSynthsMap removeObjectForKey:track];
}

- (id<MIKMIDICommandScheduler>)commandSchedulerForTrack:(MIKMIDITrack *)track
{
    id<MIKMIDICommandScheduler> result = [self.tracksToDestinationsMap objectForKey:track];
    if (!result && self.shouldCreateSynthsIfNeeded) {
        // Create a default synthesizer
        NSError *error = nil;
        result = [[MIKMIDISynthesizer alloc] initWithError:&error];
        if (!result) {
            NSLog(@"Error creating default synthesizer for %@: %@", track, error);
            return nil;
        }
        [self setCommandScheduler:result forTrack:track];
        [self.tracksToDefaultSynthsMap setObject:result forKey:track];
    }
    return result;
}

- (MIKMIDISynthesizer *)builtinSynthesizerForTrack:(MIKMIDITrack *)track
{
    [[self commandSchedulerForTrack:track] self]; // Will force creation of a synth if one doesn't exist, but should
    return [self.tracksToDefaultSynthsMap objectForKey:track];
}

#pragma mark - Click Track

- (NSMutableArray *)clickTrackEventsFromTimeStamp:(MusicTimeStamp)fromTimeStamp toTimeStamp:(MusicTimeStamp)toTimeStamp
{
    if (!self.metronome) return [NSMutableArray array];

    MIKMIDISequencerClickTrackStatus clickTrackStatus = self.clickTrackStatus;
    if (clickTrackStatus == MIKMIDISequencerClickTrackStatusDisabled) return nil;
    if (!self.isRecording && clickTrackStatus != MIKMIDISequencerClickTrackStatusAlwaysEnabled) return nil;

    NSMutableArray *clickEvents = [NSMutableArray array];
    MIKMIDIMetronome *metronome = self.metronome;
    MIDINoteMessage tickMessage = metronome.tickMessage;
    MIDINoteMessage tockMessage = metronome.tockMessage;

    MIKMIDISequence *sequence = self.sequence;
    MIKMIDITimeSignature timeSignature = [sequence timeSignatureAtTimeStamp:MAX(fromTimeStamp, 0)];
    NSMutableArray *timeSignatureEvents = [[sequence.tempoTrack eventsOfClass:[MIKMIDIMetaTimeSignatureEvent class]
                                                                fromTimeStamp:MAX(fromTimeStamp, 0)
                                                                  toTimeStamp:MAX(toTimeStamp, 0)] mutableCopy];

    MusicTimeStamp clickTimeStamp = floor(fromTimeStamp);
    while (clickTimeStamp <= toTimeStamp) {
        if (clickTrackStatus == MIKMIDISequencerClickTrackStatusEnabledOnlyInPreRoll && clickTimeStamp >= self.initialStartingTimeStamp + self.preRoll) break;

        MIKMIDIMetaTimeSignatureEvent *event = [timeSignatureEvents firstObject];
        if (event && event.timeStamp <= clickTimeStamp) {
            timeSignature = (MIKMIDITimeSignature) { .numerator = event.numerator, .denominator = event.denominator };
            [timeSignatureEvents removeObjectAtIndex:0];
        }

        if (clickTimeStamp >= fromTimeStamp) {	// ignore if clickTimeStamp is still less than fromTimeStamp (from being floored)
            NSInteger adjustedTimeStamp = clickTimeStamp * timeSignature.denominator / 4.0;
            BOOL isTick = !((adjustedTimeStamp + timeSignature.numerator) % (timeSignature.numerator));
            MIDINoteMessage clickMessage = isTick ? tickMessage : tockMessage;
            MIKMIDINoteEvent *noteEvent = [MIKMIDINoteEvent noteEventWithTimeStamp:clickTimeStamp message:clickMessage];
            [clickEvents addObject:[MIKMIDIEventWithDestination eventWithDestination:metronome event:noteEvent]];
        }

        clickTimeStamp += 4.0 / timeSignature.denominator;
    }

    return clickEvents;
}

#pragma mark - Loop Points

- (void)setLoopStartTimeStamp:(MusicTimeStamp)loopStartTimeStamp endTimeStamp:(MusicTimeStamp)loopEndTimeStamp
{
    if (loopEndTimeStamp != MIKMIDISequencerEndOfSequenceLoopEndTimeStamp && (loopStartTimeStamp >= loopEndTimeStamp)) return;

    [self dispatchSyncToProcessingQueueAsNeeded:^{
        [self willChangeValueForKey:@"loopStartTimeStamp"];
        [self willChangeValueForKey:@"loopEndTimeStamp"];

        self->_loopStartTimeStamp = loopStartTimeStamp;
        self->_loopEndTimeStamp = loopEndTimeStamp;

        [self didChangeValueForKey:@"loopStartTimeStamp"];
        [self didChangeValueForKey:@"loopEndTimeStamp"];
    }];
}

#pragma mark - Timer

- (void)processingTimerFired:(NSTimer *)timer
{
    [self processSequenceStartingFromMIDITimeStamp:self.latestScheduledMIDITimeStamp + 1];
}

#pragma mark - KVO

+ (BOOL)automaticallyNotifiesObserversOfSequence { return NO; }
+ (NSSet *)keyPathsForValuesAffectingEffectiveLoopEndTimeStamp { return [NSSet setWithObjects:@"loopEndTimeStamp", @"sequence.length", nil]; }

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSSet *currentTracks = [NSSet setWithArray:self.sequence.tracks];

    NSMapTable *tracksToDestinationMap = self.tracksToDestinationsMap;
    NSMutableSet *tracksToRemoveFromDestinationMap = [NSMutableSet setWithArray:[[tracksToDestinationMap keyEnumerator] allObjects]];
    [tracksToRemoveFromDestinationMap minusSet:currentTracks];

    for (MIKMIDITrack *track in tracksToRemoveFromDestinationMap) {
        [tracksToDestinationMap removeObjectForKey:track];
    }

    NSMapTable *tracksToSynthsMap = self.tracksToDefaultSynthsMap;
    NSMutableSet *tracksToRemoveFromSynthsMap = [NSMutableSet setWithArray:[[tracksToSynthsMap keyEnumerator] allObjects]];
    [tracksToRemoveFromSynthsMap minusSet:currentTracks];

    for (MIKMIDITrack *track in tracksToRemoveFromSynthsMap) {
        [tracksToSynthsMap removeObjectForKey:track];
    }
}

#pragma mark - Properties

@synthesize currentTimeStamp = _currentTimeStamp;
- (MusicTimeStamp)currentTimeStamp
{
    MIKMIDIClock *clock = self.clock;
    if (clock.isReady) {
        MusicTimeStamp timeStamp = [clock musicTimeStampForMIDITimeStamp:MIKMIDIGetCurrentTimeStamp()];
        _currentTimeStamp = MAX(((timeStamp <= self.sequenceLength) ? timeStamp : self.sequenceLength), self.startingTimeStamp);
    }
    return _currentTimeStamp;
}

- (void)setCurrentTimeStamp:(MusicTimeStamp)currentTimeStamp
{
    if (self.isPlaying) {
        BOOL isRecording = self.isRecording;
        [self stop];
        if (isRecording) [self prepareForRecordingWithPreRoll:NO];
        [self startPlaybackAtTimeStamp:currentTimeStamp adjustForPreRollWhenRecording:NO];
    } else {
        _currentTimeStamp = currentTimeStamp;
    }
}

- (MusicTimeStamp)effectiveLoopEndTimeStamp
{
    return (_loopEndTimeStamp < 0) ? self.sequenceLength : _loopEndTimeStamp;
}

- (void)setPreRoll:(MusicTimeStamp)preRoll
{
    _preRoll = (preRoll >= 0) ? preRoll : 0;
}

- (void)setProcessingTimer:(dispatch_source_t)processingTimer
{
    if (_processingTimer != processingTimer) {
        if (_processingTimer) {
            dispatch_source_cancel(_processingTimer);
        }
        _processingTimer = processingTimer;
    }
}

@synthesize metronome = _metronome;
- (MIKMIDIMetronome *)metronome
{
#if (TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0) || !TARGET_OS_IPHONE
    if (!_metronome) _metronome = [[MIKMIDIMetronome alloc] initWithError:NULL];
    return _metronome;
#else
    return nil;
#endif
}

- (void)setTempo:(Float64)tempo
{
    if (tempo < 0) tempo = 0;
    if (_tempo != tempo) {
        _tempo = tempo;
        if (self.isPlaying) self.needsCurrentTempoUpdate = YES;
    }
}

- (MusicTimeStamp)sequenceLength
{
    MusicTimeStamp length = self.overriddenSequenceLength;
    return length ? length : self.sequence.length;
}

- (void)setSequence:(MIKMIDISequence *)sequence
{
    if (_sequence != sequence) {
        [self dispatchSyncToProcessingQueueAsNeeded:^{
            [self willChangeValueForKey:@"sequence"];
            [self->_sequence removeObserver:self forKeyPath:@"tracks"];

            if (self->_sequence.sequencer == self) self->_sequence.sequencer = nil;
            self->_sequence = sequence;
            self->_sequence.sequencer = self;

            [self->_sequence addObserver:self forKeyPath:@"tracks" options:NSKeyValueObservingOptionInitial context:NULL];
            [self didChangeValueForKey:@"sequence"];
        }];
    }
}

- (void)setMaximumLookAheadInterval:(NSTimeInterval)maximumLookAheadInterval
{
    _maximumLookAheadInterval = MIN(MAX(maximumLookAheadInterval, 0.05), 1.0);
}

#pragma mark - Deprecated

- (void)setDestinationEndpoint:(MIKMIDIDestinationEndpoint *)endpoint forTrack:(MIKMIDITrack *)track
{
    [self setCommandScheduler:endpoint forTrack:track];
}

- (MIKMIDIDestinationEndpoint *)destinationEndpointForTrack:(MIKMIDITrack *)track
{
    id<MIKMIDICommandScheduler> commandScheduler = [self commandSchedulerForTrack:track];
    return [commandScheduler isKindOfClass:[MIKMIDIDestinationEndpoint class]] ? commandScheduler : nil;
}

@end


#pragma mark -
@implementation MIKMIDISequencer (MIKMIDIPrivate)

- (void)dispatchSyncToProcessingQueueAsNeeded:(void (^)(void))block
{
    if (!block) return;

    dispatch_queue_t processingQueue = self.processingQueue;
    if (processingQueue && dispatch_get_specific(_processingQueueKey) != _processingQueueContext) {
        dispatch_sync(processingQueue, block);
    } else {
        block();
    }
}

@end


#pragma mark -
@implementation MIKMIDIEventWithDestination

+ (instancetype)eventWithDestination:(id<MIKMIDICommandScheduler>)destination event:(MIKMIDIEvent *)event
{
    return [self eventWithDestination:destination event:event representsNoteOff:NO];
}

+ (instancetype)eventWithDestination:(id<MIKMIDICommandScheduler>)destination event:(MIKMIDIEvent *)event representsNoteOff:(BOOL)representsNoteOff
{
    MIKMIDIEventWithDestination *destinationEvent = [[self alloc] init];
    destinationEvent->_event = event;
    destinationEvent->_destination = destination;
    destinationEvent->_representsNoteOff = representsNoteOff;
    return destinationEvent;
}

@end


@implementation MIKMIDICommandWithDestination

+ (instancetype)commandWithDestination:(id<MIKMIDICommandScheduler>)destination command:(MIKMIDICommand *)command
{
    MIKMIDICommandWithDestination *destinationCommand = [[self alloc] init];
    destinationCommand->_destination = destination;
    destinationCommand->_command = command;
    return destinationCommand;
}

@end


@implementation MIKMIDIPendingNoteOffsForTimeStamp

+ (instancetype)pendingNoteOffWithEndTimeStamp:(MusicTimeStamp)endTimeStamp
{
    MIKMIDIPendingNoteOffsForTimeStamp *noteOff = [[self alloc] init];
    noteOff->_endTimeStamp = endTimeStamp;
    return noteOff;
}

- (NSMutableArray *)noteEventsWithEndTimeStamp
{
    if (!_noteEventsWithEndTimeStamp) _noteEventsWithEndTimeStamp = [NSMutableArray array];
    return _noteEventsWithEndTimeStamp;
}

@end
